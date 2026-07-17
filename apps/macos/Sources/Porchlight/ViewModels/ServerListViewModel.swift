import Foundation

@MainActor
@Observable
final class ServerListViewModel {
    private let cli = PorchlightCLI()
    private var hasStarted = false

    var servers: [LocalServer] = []
    var errorMessage: String?
    var isRefreshing = false
    var killingServerIDs: Set<String> = []
    var lastRefreshedAt: Date?

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
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            servers = try await cli.listServers()
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
        do {
            try await cli.removeServer(server)
            errorMessage = nil
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func killAndRemove(_ server: LocalServer) async {
        await kill(server)
        await remove(server)
    }
}
