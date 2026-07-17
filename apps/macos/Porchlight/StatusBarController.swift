import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let cli = PorchlightCLI()
    private let mainWindowController: SettingsWindowController
    private var servers: [LocalServer] = []
    private var refreshTask: Task<Void, Never>?
    private var activeRefreshTask: Task<Void, Never>?
    private var startingServerIDs: Set<String> = []
    private var killingServerIDs: Set<String> = []
    private var isMenuOpen = false

    init(mainWindowController: SettingsWindowController) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.mainWindowController = mainWindowController
        super.init()

        statusItem.button?.image = PorchlightStatusIcon.image(isActive: false)
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
            try? await Task.sleep(for: .seconds(2))
            scheduleRefresh()
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
            servers = try await cli.listServers()
            statusItem.button?.image = PorchlightStatusIcon.image(isActive: servers.contains { $0.isActive })
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func rebuildMenu(error: String? = nil) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        populate(menu, error: error)
        statusItem.menu = menu
    }

    private func populate(_ menu: NSMenu, error: String? = nil) {
        menu.removeAllItems()

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
            addServerItems(to: menu)
        }

        menu.addItem(.separator())

        menu.addItem(refreshMenuItem())
        menu.addItem(killAllMenuItem())

        menu.addItem(.separator())

        let open = NSMenuItem(title: "Open Porchlight", action: #selector(openPorchlight), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        let quit = NSMenuItem(title: "Quit Porchlight", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func repaintOpenMenu(error: String? = nil) {
        guard isMenuOpen, let menu = statusItem.menu else { return }
        populate(menu, error: error)
    }

    private func addServerItems(to menu: NSMenu) {
        var groups: [(group: ServerGroupMatch, servers: [LocalServer])] = []
        var ungroupedServers: [LocalServer] = []

        for server in servers {
            guard let group = server.group else {
                ungroupedServers.append(server)
                continue
            }

            if let index = groups.firstIndex(where: { $0.group.id == group.id }) {
                groups[index].servers.append(server)
            } else {
                groups.append((group, [server]))
            }
        }

        var addedSection = false

        for group in groups {
            if addedSection {
                menu.addItem(.separator())
            }
            menu.addItem(groupHeaderItem(for: group.group))
            group.servers.forEach { menu.addItem(menuItem(for: $0)) }
            addedSection = true
        }

        if !ungroupedServers.isEmpty {
            if addedSection {
                menu.addItem(.separator())
            }
            ungroupedServers.forEach { menu.addItem(menuItem(for: $0)) }
        }
    }

    private func groupHeaderItem(for group: ServerGroupMatch) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.image = groupIconImage(group.icon)
        item.attributedTitle = NSAttributedString(
            string: group.name,
            attributes: [
                .font: NSFont.menuFont(ofSize: 11),
                .foregroundColor: NSColor(hex: group.color) ?? NSColor.secondaryLabelColor
            ]
        )
        return item
    }

    private func groupIconImage(_ icon: String?) -> NSImage? {
        guard let icon = icon?.trimmingCharacters(in: .whitespacesAndNewlines), !icon.isEmpty else {
            return nil
        }

        let path: String
        if let url = URL(string: icon), url.isFileURL {
            path = url.path
        } else if icon.hasPrefix("~") {
            path = (icon as NSString).expandingTildeInPath
        } else {
            path = icon
        }

        guard let image = NSImage(contentsOfFile: path) else { return nil }
        image.size = NSSize(width: 14, height: 14)
        image.isTemplate = false
        return image
    }

    private func serverIconImage(_ server: LocalServer) -> NSImage? {
        groupIconImage(server.icon ?? server.group?.icon)
    }

    private func menuItem(for server: LocalServer) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")

        if isBusy(server) {
            item.view = ServerMenuItemView(server: server)
            return item
        }

        item.attributedTitle = serverMenuTitle(server)
        item.image = serverIconImage(server) ?? statusImage(isActive: server.isActive)
        item.submenu = submenu(for: server)
        return item
    }

    private func isBusy(_ server: LocalServer) -> Bool {
        startingServerIDs.contains(server.id) || killingServerIDs.contains(server.id)
    }

    private func refreshMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        item.view = RefreshMenuItemView(
            title: "Refresh",
            shortcut: "⌘R",
            target: self,
            action: #selector(refreshNow)
        )
        return item
    }

    private func killAllMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        item.view = RefreshMenuItemView(
            title: "Kill All",
            isEnabled: servers.contains { $0.isActive },
            target: self,
            action: #selector(killAll)
        )
        return item
    }

    private func submenu(for server: LocalServer) -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        let location = NSMenuItem(title: server.locationText, action: nil, keyEquivalent: "")
        location.isEnabled = false
        submenu.addItem(location)

        submenu.addItem(.separator())

        let openAddress = NSMenuItem(title: displayURL(server.url), action: #selector(openAddress(_:)), keyEquivalent: "")
        openAddress.target = self
        openAddress.representedObject = server.id
        submenu.addItem(openAddress)

        if server.workingDirectory != nil {
            let finder = NSMenuItem(title: "Open in Finder", action: #selector(openInFinder(_:)), keyEquivalent: "")
            finder.target = self
            finder.representedObject = server.id
            submenu.addItem(finder)

            let openInApp = NSMenuItem(title: "Open in App", action: nil, keyEquivalent: "")
            openInApp.submenu = openInAppSubmenu(for: server)
            submenu.addItem(openInApp)
        }

        submenu.addItem(.separator())

        let process = NSMenuItem(title: "pid \(server.pid) • \(server.processName)", action: nil, keyEquivalent: "")
        process.isEnabled = false
        submenu.addItem(process)

        let command = NSMenuItem(title: "Command", action: nil, keyEquivalent: "")
        command.submenu = commandSubmenu(for: server)
        submenu.addItem(command)

        submenu.addItem(.separator())

        if server.isActive {
            let pin = pinMenuItem(for: server)
            submenu.addItem(pin)

            submenu.addItem(killMenuItem(for: server))

            let killAndRemove = NSMenuItem(title: "Kill and Remove", action: #selector(killAndRemove(_:)), keyEquivalent: "")
            killAndRemove.target = self
            killAndRemove.representedObject = server.id
            submenu.addItem(killAndRemove)
        } else {
            let pin = pinMenuItem(for: server)
            submenu.addItem(pin)

            submenu.addItem(startMenuItem(for: server))

            let remove = NSMenuItem(title: "Remove", action: #selector(remove(_:)), keyEquivalent: "")
            remove.target = self
            remove.representedObject = server.id
            submenu.addItem(remove)
        }

        return submenu
    }

    private func pinMenuItem(for server: LocalServer) -> NSMenuItem {
        let item = NSMenuItem(title: server.pinned ? "Unpin" : "Pin", action: #selector(togglePin(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = server.id
        return item
    }

    private func startMenuItem(for server: LocalServer) -> NSMenuItem {
        let item = NSMenuItem()
        item.view = StartMenuItemView(
            serverID: server.id,
            isEnabled: server.resolvedStartCommand != nil,
            isStarting: startingServerIDs.contains(server.id),
            target: self,
            action: #selector(startServer(_:))
        )
        return item
    }

    private func killMenuItem(for server: LocalServer) -> NSMenuItem {
        let item = NSMenuItem()
        item.view = StartMenuItemView(
            serverID: server.id,
            title: "Kill",
            busyTitle: "Killing…",
            isEnabled: true,
            isStarting: killingServerIDs.contains(server.id),
            target: self,
            action: #selector(killServer(_:))
        )
        return item
    }

    private func openInAppSubmenu(for server: LocalServer) -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        let code = NSMenuItem(title: "Visual Studio Code", action: #selector(openInVSCode(_:)), keyEquivalent: "")
        code.target = self
        code.representedObject = server.id
        submenu.addItem(code)

        let xcode = NSMenuItem(title: "Xcode", action: #selector(openInXcode(_:)), keyEquivalent: "")
        xcode.target = self
        xcode.representedObject = server.id
        xcode.isEnabled = canOpenInXcode(server)
        submenu.addItem(xcode)

        return submenu
    }

    private func commandSubmenu(for server: LocalServer) -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        let preview = NSMenuItem(title: shortened(server.command, limit: 72), action: nil, keyEquivalent: "")
        preview.isEnabled = false
        submenu.addItem(preview)

        let copy = NSMenuItem(title: "Copy Command", action: #selector(copyCommand(_:)), keyEquivalent: "")
        copy.target = self
        copy.representedObject = server.id
        submenu.addItem(copy)

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

    private func serverMenuTitle(_ server: LocalServer) -> NSAttributedString {
        let title = NSMutableAttributedString(
            string: String(server.port),
            attributes: [
                .font: NSFont.menuFont(ofSize: 0),
                .foregroundColor: NSColor.labelColor
            ]
        )

        title.append(NSAttributedString(string: "  "))
        title.append(NSAttributedString(
            string: server.serverType,
            attributes: [
                .font: NSFont.menuFont(ofSize: 0),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        ))

        return title
    }

    @objc private func refreshNow() {
        Task { [weak self] in
            guard let self else { return }
            let error = await loadServers()
            if let menu = statusItem.menu {
                populate(menu, error: error)
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

    private func canOpenInXcode(_ server: LocalServer) -> Bool {
        guard let workingDirectory = server.workingDirectory else { return false }
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: workingDirectory)) ?? []
        return contents.contains { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }
    }

    private func shortened(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit - 1)) + "…"
    }

    private func displayURL(_ value: String) -> String {
        guard let url = URL(string: value), let host = url.host else { return value }

        if let port = url.port {
            return "\(host):\(port)"
        }

        return host
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
