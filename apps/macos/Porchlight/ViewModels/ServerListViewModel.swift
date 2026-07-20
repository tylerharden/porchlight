import AppKit
import Foundation

@MainActor
@Observable
final class ServerListViewModel {
    private let cli = PorchlightCLI()
    private let settings: AppSettings?
    private var hasStarted = false

    var servers: [LocalServer] = []
    var errorMessage: String?
    var isRefreshing = false
    var killingServerIDs: Set<String> = []
    var startingServerIDs: Set<String> = []
    var lastRefreshedAt: Date?

    init(settings: AppSettings? = nil) {
        self.settings = settings
    }

    var hasActiveServers: Bool {
        servers.contains { $0.isActive }
    }

    var activeServerCount: Int {
        servers.filter { $0.isActive }.count
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true

        await refresh()

        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            await refresh()
        }
    }

    func refresh() async {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            servers = try await cli.listServers(
                showAutomaticGroups: settings?.showAutomaticGroups ?? true,
                showAppServices: settings?.showAppServices ?? true
            )
            errorMessage = nil
            lastRefreshedAt = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func kill(_ server: LocalServer) async {
        guard !killingServerIDs.contains(server.id) else { return }

        killingServerIDs.insert(server.id)
        defer { killingServerIDs.remove(server.id) }

        do {
            try await cli.killServer(server)
            errorMessage = nil
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(_ server: LocalServer) async {
        await performServerAction { try await cli.removeServer(server) }
    }

    func hide(_ server: LocalServer) async {
        await performServerAction { try await cli.hideServer(server) }
    }

    func killAndRemove(_ server: LocalServer) async {
        await kill(server)
        await remove(server)
    }

    func start(_ server: LocalServer) async {
        guard let startCommand = server.resolvedStartCommand else { return }
        guard !startingServerIDs.contains(server.id) else { return }

        startingServerIDs.insert(server.id)
        defer { startingServerIDs.remove(server.id) }

        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", startCommand]
            if let workingDirectory = server.workingDirectory {
                process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
            }
            try process.run()
            errorMessage = nil
            await refresh()
            await refreshUntilActive(serverID: server.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshUntilActive(serverID: String) async {
        for _ in 0..<10 {
            try? await Task.sleep(for: .milliseconds(700))
            await refresh()

            if servers.contains(where: { $0.id == serverID && $0.isActive }) {
                return
            }
        }
    }

    func togglePin(_ server: LocalServer) async {
        await performServerAction {
            if server.pinned {
                try await cli.unpinServer(server)
            } else {
                try await cli.pinServer(server)
            }
        }
    }

    private func performServerAction(_ action: () async throws -> Void) async {
        do {
            try await action()
            errorMessage = nil
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func open(_ server: LocalServer) {
        guard let url = URL(string: server.url) else { return }
        NSWorkspace.shared.open(url)
    }

    func openInFinder(_ server: LocalServer) {
        guard let workingDirectory = server.workingDirectory else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: workingDirectory))
    }

    func openInVSCode(_ server: LocalServer) {
        guard let workingDirectory = server.workingDirectory else { return }
        runAppCommand("/usr/local/bin/code", argument: workingDirectory)
    }

    func openInXcode(_ server: LocalServer) {
        guard let workingDirectory = server.workingDirectory else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: workingDirectory))
    }

    private func runAppCommand(_ executable: String, argument: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = [argument]
        try? process.run()
    }
}
