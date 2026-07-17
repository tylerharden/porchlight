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

    func listServers() async throws -> [LocalServer] {
        let data = try await run(arguments: ["list", "--json"])
        return try JSONDecoder().decode(ServerListResponse.self, from: data).servers
    }

    func killServer(_ server: LocalServer) async throws {
        _ = try await run(arguments: ["kill", server.id])
    }

    func removeServer(_ server: LocalServer) async throws {
        _ = try await run(arguments: ["remove", server.id])
    }

    private func run(arguments: [String]) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
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

            try process.run()
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
