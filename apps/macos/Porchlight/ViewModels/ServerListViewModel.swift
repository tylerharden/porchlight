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
    var hasLoadedServers = false
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

    var isLoadingInitialServers: Bool {
        !hasLoadedServers && errorMessage == nil
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
                showAppServices: settings?.showAppServices ?? true,
                includeHidden: true
            )
            errorMessage = nil
            lastRefreshedAt = Date()
        } catch {
            errorMessage = error.localizedDescription
        }

        if !hasLoadedServers {
            hasLoadedServers = true
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

    func unhide(_ server: LocalServer) async {
        await performServerAction { try await cli.unhideServer(server) }
    }

    func killAndRemove(_ server: LocalServer) async {
        await kill(server)
        await remove(server)
    }

    func start(_ server: LocalServer) async {
        guard server.resolvedStartCommand != nil else { return }
        guard !startingServerIDs.contains(server.id) else { return }

        startingServerIDs.insert(server.id)
        defer { startingServerIDs.remove(server.id) }

        do {
            try ServerActions.start(server)
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
        ServerActions.open(server)
    }

    func openInFinder(_ server: LocalServer) {
        ServerActions.openInFinder(server)
    }

    func openInVSCode(_ server: LocalServer) {
        ServerActions.openInVSCode(server)
    }

    func openInXcode(_ server: LocalServer) {
        ServerActions.openInXcode(server)
    }
}
