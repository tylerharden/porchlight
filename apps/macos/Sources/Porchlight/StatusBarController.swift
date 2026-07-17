import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let cli = PorchlightCLI()
    private var servers: [LocalServer] = []
    private var refreshTask: Task<Void, Never>?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: "lightbulb", accessibilityDescription: "Porchlight")
        statusItem.button?.imagePosition = .imageOnly

        rebuildMenu()
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
            try? await Task.sleep(for: .seconds(5))
            await refresh()
        }
    }

    private func refresh() async {
        do {
            servers = try await cli.listServers()
            statusItem.button?.image = NSImage(
                systemSymbolName: servers.contains { $0.isActive } ? "lightbulb.fill" : "lightbulb",
                accessibilityDescription: "Porchlight"
            )
            rebuildMenu()
        } catch {
            rebuildMenu(error: error.localizedDescription)
        }
    }

    private func rebuildMenu(error: String? = nil) {
        let menu = NSMenu()
        menu.autoenablesItems = false

        if let error {
            let title = NSMenuItem(title: "Porchlight CLI failed", action: nil, keyEquivalent: "")
            title.isEnabled = false
            menu.addItem(title)

            let detail = NSMenuItem(title: error, action: nil, keyEquivalent: "")
            detail.isEnabled = false
            menu.addItem(detail)
        } else if servers.isEmpty {
            let empty = NSMenuItem(title: "No local servers running", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for server in servers {
                menu.addItem(menuItem(for: server))
            }
        }

        menu.addItem(.separator())

        let refresh = NSMenuItem(title: "Refresh", action: #selector(refreshNow), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "Quit Porchlight", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func menuItem(for server: LocalServer) -> NSMenuItem {
        let item = NSMenuItem(title: "\(server.port)  \(server.serverType)", action: nil, keyEquivalent: "")
        item.image = statusImage(isActive: server.isActive)
        item.submenu = submenu(for: server)
        return item
    }

    private func submenu(for server: LocalServer) -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        let location = NSMenuItem(title: server.locationText, action: nil, keyEquivalent: "")
        location.isEnabled = false
        submenu.addItem(location)

        submenu.addItem(.separator())

        let openAddress = NSMenuItem(title: "Open Address", action: #selector(openAddress(_:)), keyEquivalent: "")
        openAddress.target = self
        openAddress.representedObject = server.id
        submenu.addItem(openAddress)

        if server.workingDirectory != nil {
            let finder = NSMenuItem(title: "Open in Finder", action: #selector(openInFinder(_:)), keyEquivalent: "")
            finder.target = self
            finder.representedObject = server.id
            submenu.addItem(finder)

            let code = NSMenuItem(title: "Open in VS Code", action: #selector(openInVSCode(_:)), keyEquivalent: "")
            code.target = self
            code.representedObject = server.id
            submenu.addItem(code)
        }

        submenu.addItem(.separator())

        let process = NSMenuItem(title: "pid \(server.pid) • \(server.processName)", action: nil, keyEquivalent: "")
        process.isEnabled = false
        submenu.addItem(process)

        let command = NSMenuItem(title: server.command, action: nil, keyEquivalent: "")
        command.isEnabled = false
        submenu.addItem(command)

        submenu.addItem(.separator())

        if server.isActive {
            let kill = NSMenuItem(title: "Kill", action: #selector(kill(_:)), keyEquivalent: "")
            kill.target = self
            kill.representedObject = server.id
            submenu.addItem(kill)

            let killAndRemove = NSMenuItem(title: "Kill and Remove", action: #selector(killAndRemove(_:)), keyEquivalent: "")
            killAndRemove.target = self
            killAndRemove.representedObject = server.id
            submenu.addItem(killAndRemove)
        } else {
            let remove = NSMenuItem(title: "Remove", action: #selector(remove(_:)), keyEquivalent: "")
            remove.target = self
            remove.representedObject = server.id
            submenu.addItem(remove)
        }

        return submenu
    }

    private func server(for menuItem: NSMenuItem) -> LocalServer? {
        guard let id = menuItem.representedObject as? String else { return nil }
        return servers.first { $0.id == id }
    }

    private func statusImage(isActive: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        (isActive ? NSColor.systemGreen : NSColor.systemGray).setFill()
        NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 6, height: 6)).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    @objc private func refreshNow() {
        Task { await refresh() }
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/code")
        process.arguments = [workingDirectory]
        try? process.run()
    }

    @objc private func kill(_ sender: NSMenuItem) {
        guard let server = server(for: sender) else { return }
        Task {
            try? await cli.killServer(server)
            await refresh()
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
}
