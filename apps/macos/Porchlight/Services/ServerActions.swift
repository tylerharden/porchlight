import Foundation

struct ServerActions {
    static func start(_ server: LocalServer) throws {
        guard let startCommand = server.resolvedStartCommand else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", startCommand]
        if let workingDirectory = server.workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }
        try process.run()
    }

    static func open(_ server: LocalServer) {
        guard let url = URL(string: server.url) else { return }
        WorkspaceOpener.open(url)
    }

    static func openInFinder(_ server: LocalServer) {
        guard let workingDirectory = server.workingDirectory else { return }
        WorkspaceOpener.open(URL(fileURLWithPath: workingDirectory))
    }

    static func openInVSCode(_ server: LocalServer) {
        guard let workingDirectory = server.workingDirectory else { return }
        runAppCommand("/usr/local/bin/code", argument: workingDirectory)
    }

    static func openInXcode(_ server: LocalServer) {
        guard let workingDirectory = server.workingDirectory else { return }
        WorkspaceOpener.open(URL(fileURLWithPath: workingDirectory))
    }

    private static func runAppCommand(_ executable: String, argument: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = [argument]
        try? process.run()
    }
}
