import Foundation

@MainActor
@Observable
final class ServerListViewModel {
    private let cli = PorchlightCLI()
    private var hasStarted = false

    var servers: [LocalServer] = []
    var errorMessage: String?
    var isRefreshing = false
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
}
