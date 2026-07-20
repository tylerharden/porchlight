import Foundation

struct PorchlightCLI {
    var executablePath: String {
        if let override = ProcessInfo.processInfo.environment["PORCHLIGHT_CLI_PATH"], !override.isEmpty {
            return override
        }

        let developmentPath = "/Users/tyler/Developer/porchlight/cli/target/debug/porchlight"
        if FileManager.default.isExecutableFile(atPath: developmentPath) {
            return developmentPath
        }

        if let bundledPath = Bundle.main.path(forResource: "porchlight", ofType: nil) {
            return bundledPath
        }

        return developmentPath
    }

    func listServers(showAutomaticGroups: Bool = true) async throws -> [LocalServer] {
        var arguments = ["list", "--json"]
        if !showAutomaticGroups {
            arguments.append("--no-auto-groups")
        }

        let data = try await run(arguments: arguments)
        return try JSONDecoder().decode(ServerListResponse.self, from: data).servers
    }

    func listGroups() async throws -> [ServerGroup] {
        let data = try await run(arguments: ["groups", "list", "--json"])
        return try JSONDecoder().decode(ServerGroupsDocument.self, from: data).groups
    }

    func replaceGroups(_ groups: [ServerGroup]) async throws {
        let data = try JSONEncoder.porchlight.encode(ServerGroupsDocument(groups: groups))
        _ = try await run(arguments: ["groups", "replace", "--stdin"], stdin: data)
    }

    func setAutomaticGroups(_ enabled: Bool) async throws {
        _ = try await run(arguments: ["config", "set-auto-groups", enabled ? "true" : "false"])
    }

    func reset() async throws {
        _ = try await run(arguments: ["reset"])
    }

    func killServer(_ server: LocalServer) async throws {
        _ = try await run(arguments: ["kill", server.id])
    }

    func removeServer(_ server: LocalServer) async throws {
        _ = try await run(arguments: ["remove", server.id])
    }

    func pinServer(_ server: LocalServer) async throws {
        _ = try await run(arguments: ["pin", server.id])
    }

    func unpinServer(_ server: LocalServer) async throws {
        _ = try await run(arguments: ["unpin", server.id])
    }

    private func run(arguments: [String], stdin: Data? = nil) async throws -> Data {
        let executablePath = executablePath

        return try await Task.detached(priority: .userInitiated) {
            guard FileManager.default.isExecutableFile(atPath: executablePath) else {
                throw PorchlightCLIError.missingExecutable(executablePath)
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.environment = [
                "HOME": FileManager.default.homeDirectoryForCurrentUser.path,
                "PATH": "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            ]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            let inputPipe: Pipe?
            if stdin != nil {
                let pipe = Pipe()
                process.standardInput = pipe
                inputPipe = pipe
            } else {
                inputPipe = nil
            }

            try process.run()

            if let stdin, let inputPipe {
                inputPipe.fileHandleForWriting.write(stdin)
                try inputPipe.fileHandleForWriting.close()
            }

            process.waitUntilExit()

            let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let error = errorPipe.fileHandleForReading.readDataToEndOfFile()

            guard process.terminationStatus == 0 else {
                let message = String(data: error, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                throw PorchlightCLIError.commandFailed(message ?? "Unknown CLI error")
            }

            return output
        }
        .value
    }
}

extension JSONEncoder {
    static let porchlight: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}

enum PorchlightCLIError: LocalizedError {
    case missingExecutable(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingExecutable(let path):
            return "Missing porchlight CLI at \(path). Run `cargo build` in the cli folder."
        case .commandFailed(let message):
            return message
        }
    }
}
