import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let cli = PorchlightCLI()
    private let mainWindowController: SettingsWindowController
    private let settings: AppSettings
    private var servers: [LocalServer] = []
    private var refreshTask: Task<Void, Never>?
    private var activeRefreshTask: Task<Void, Never>?
    private var settingsObserver: NSObjectProtocol?
    private var groupObserver: NSObjectProtocol?
    private var startingServerIDs: Set<String> = []
    private var killingServerIDs: Set<String> = []
    private var isMenuOpen = false

    private var menuBuilder: StatusMenuBuilder {
        StatusMenuBuilder(
            target: self,
            delegate: self,
            actions: StatusMenuBuilder.Actions(
                refresh: #selector(refreshNow),
                openPorchlight: #selector(openPorchlight),
                quit: #selector(quit),
                openAddress: #selector(openAddress(_:)),
                openInFinder: #selector(openInFinder(_:)),
                openInVSCode: #selector(openInVSCode(_:)),
                openInXcode: #selector(openInXcode(_:)),
                copyCommand: #selector(copyCommand(_:)),
                startServer: #selector(startServer(_:)),
                killServer: #selector(killServer(_:)),
                killAll: #selector(killAll),
                killAndRemove: #selector(killAndRemove(_:)),
                remove: #selector(remove(_:)),
                hide: #selector(hide(_:)),
                togglePin: #selector(togglePin(_:))
            ),
            showGroupIcons: settings.showGroupIcons
        )
    }

    init(mainWindowController: SettingsWindowController, settings: AppSettings) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.mainWindowController = mainWindowController
        self.settings = settings
        super.init()

        statusItem.button?.image = PorchlightStatusIcon.image(isActive: false)
        statusItem.button?.imagePosition = .imageOnly

        rebuildMenu()
        applyMenuVisibility()
        settingsObserver = NotificationCenter.default.addObserver(
            forName: AppSettings.didChangeNotification,
            object: settings,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.applyMenuVisibility()
            }
        }
        groupObserver = NotificationCenter.default.addObserver(
            forName: ServerGroupStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh(rebuildWhileOpen: true)
            }
        }
        refreshTask = Task { [weak self] in
            await self?.refreshLoop()
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    private func refreshLoop() async {
        await refresh()

        while !Task.isCancelled {
            let interval = UInt64(max(1, settings.refreshInterval) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: interval)
            if settings.autoRefresh {
                scheduleRefresh()
            }
        }
    }

    private func scheduleRefresh() {
        guard activeRefreshTask == nil else { return }

        activeRefreshTask = Task { [weak self] in
            await self?.refresh()
            self?.activeRefreshTask = nil
        }
    }

    private func refresh(rebuildWhileOpen: Bool = false) async {
        let error = await loadServers()
        if rebuildWhileOpen || !isMenuOpen {
            rebuildMenu(error: error)
        }
    }

    private func loadServers() async -> String? {
        do {
            servers = try await cli.listServers(
                showAutomaticGroups: settings.showAutomaticGroups,
                showAppServices: settings.showAppServices
            )
            statusItem.button?.image = PorchlightStatusIcon.image(isActive: servers.contains { $0.isActive })
            applyMenuVisibility()
            return nil
        } catch {
            applyMenuVisibility()
            return error.localizedDescription
        }
    }

    private func applyMenuVisibility() {
        statusItem.isVisible = !settings.hideMenuIconWhenEmpty || servers.contains { $0.isActive }
    }

    private func rebuildMenu(error: String? = nil) {
        statusItem.menu = menuBuilder.menu(
            servers: servers,
            startingServerIDs: startingServerIDs,
            killingServerIDs: killingServerIDs,
            error: error
        )
    }

    private func repaintOpenMenu(error: String? = nil) {
        guard isMenuOpen, let menu = statusItem.menu else { return }
        menuBuilder.populate(
            menu,
            servers: servers,
            startingServerIDs: startingServerIDs,
            killingServerIDs: killingServerIDs,
            error: error
        )
    }

    private func server(for menuItem: NSMenuItem) -> LocalServer? {
        guard let id = menuItem.representedObject as? String else { return nil }
        return servers.first { $0.id == id }
    }

    @objc private func refreshNow() {
        Task { [weak self] in
            guard let self else { return }
            let error = await loadServers()
            if let menu = statusItem.menu {
                menuBuilder.populate(
                    menu,
                    servers: servers,
                    startingServerIDs: startingServerIDs,
                    killingServerIDs: killingServerIDs,
                    error: error
                )
            } else {
                rebuildMenu(error: error)
            }
        }
    }

    @objc private func openPorchlight() {
        mainWindowController.show()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func openAddress(_ sender: NSMenuItem) {
        guard let server = server(for: sender), let url = URL(string: server.url) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func openInFinder(_ sender: NSMenuItem) {
        guard let server = server(for: sender), let workingDirectory = server.workingDirectory else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: workingDirectory))
    }

    @objc private func openInVSCode(_ sender: NSMenuItem) {
        guard let server = server(for: sender), let workingDirectory = server.workingDirectory else { return }
        runAppCommand("/usr/local/bin/code", argument: workingDirectory)
    }

    @objc private func openInXcode(_ sender: NSMenuItem) {
        guard let server = server(for: sender), let workingDirectory = server.workingDirectory else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: workingDirectory))
    }

    @objc private func copyCommand(_ sender: NSMenuItem) {
        guard let server = server(for: sender) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(server.command, forType: .string)
    }

    @objc private func startServer(_ sender: Any?) {
        guard let serverID = sender as? String,
              let server = servers.first(where: { $0.id == serverID }),
              let startCommand = server.resolvedStartCommand,
              !startingServerIDs.contains(server.id)
        else { return }

        startingServerIDs.insert(server.id)
        repaintOpenMenu()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", startCommand]
        if let workingDirectory = server.workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }
        try? process.run()

        Task { [weak self] in
            await self?.refreshUntilActive(serverID: server.id)
        }
    }

    @objc private func killServer(_ sender: Any?) {
        guard let serverID = sender as? String,
              let server = servers.first(where: { $0.id == serverID }),
              !killingServerIDs.contains(server.id)
        else { return }

        killingServerIDs.insert(server.id)
        repaintOpenMenu()

        Task { [weak self] in
            guard let self else { return }
            try? await cli.killServer(server)
            await refresh()
            killingServerIDs.remove(server.id)
            if isMenuOpen {
                repaintOpenMenu()
            } else {
                rebuildMenu()
            }
        }
    }

    @objc private func killAll() {
        let activeServers = servers.filter { $0.isActive }
        guard !activeServers.isEmpty else { return }

        activeServers.forEach { killingServerIDs.insert($0.id) }
        repaintOpenMenu()

        Task { [weak self] in
            guard let self else { return }
            for server in activeServers {
                try? await cli.killServer(server)
            }
            await refresh()
            activeServers.forEach { killingServerIDs.remove($0.id) }
            if isMenuOpen {
                repaintOpenMenu()
            } else {
                rebuildMenu()
            }
        }
    }

    private func refreshUntilActive(serverID: String) async {
        await refresh()

        for _ in 0..<10 {
            try? await Task.sleep(for: .milliseconds(700))
            await refresh()

            if servers.contains(where: { $0.id == serverID && $0.isActive }) {
                startingServerIDs.remove(serverID)
                if isMenuOpen {
                    repaintOpenMenu()
                } else {
                    rebuildMenu()
                }
                return
            }
        }

        startingServerIDs.remove(serverID)
        if isMenuOpen {
            repaintOpenMenu()
        } else {
            rebuildMenu()
        }
    }

    @objc private func killAndRemove(_ sender: NSMenuItem) {
        guard let server = server(for: sender) else { return }
        Task {
            try? await cli.killServer(server)
            try? await cli.removeServer(server)
            await refresh()
        }
    }

    @objc private func remove(_ sender: NSMenuItem) {
        guard let server = server(for: sender) else { return }
        Task {
            try? await cli.removeServer(server)
            await refresh()
        }
    }

    @objc private func hide(_ sender: NSMenuItem) {
        guard let server = server(for: sender) else { return }
        Task {
            try? await cli.hideServer(server)
            await refresh()
        }
    }

    @objc private func togglePin(_ sender: NSMenuItem) {
        guard let server = server(for: sender) else { return }
        Task {
            if server.pinned {
                try? await cli.unpinServer(server)
            } else {
                try? await cli.pinServer(server)
            }
            await refresh()
        }
    }

    private func runAppCommand(_ executable: String, argument: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = [argument]
        try? process.run()
    }
}

extension StatusBarController: NSMenuDelegate {
    nonisolated func menuWillOpen(_ menu: NSMenu) {
        Task { @MainActor in
            self.isMenuOpen = true
            self.scheduleRefresh()
        }
    }

    nonisolated func menuDidClose(_ menu: NSMenu) {
        Task { @MainActor in
            self.isMenuOpen = false
            self.scheduleRefresh()
        }
    }
}
