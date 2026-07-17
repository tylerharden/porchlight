import AppKit

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let cli = PorchlightCLI()
    private let mainWindowController: SettingsWindowController
    private var servers: [LocalServer] = []
    private var refreshTask: Task<Void, Never>?
    private var activeRefreshTask: Task<Void, Never>?

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

    private func refresh() async {
        do {
            servers = try await cli.listServers()
            statusItem.button?.image = PorchlightStatusIcon.image(isActive: servers.contains { $0.isActive })
            rebuildMenu()
        } catch {
            rebuildMenu(error: error.localizedDescription)
        }
    }

    private func rebuildMenu(error: String? = nil) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

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

        menu.addItem(.separator())

        let open = NSMenuItem(title: "Open Porchlight", action: #selector(openPorchlight), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        let quit = NSMenuItem(title: "Quit Porchlight", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
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
        item.attributedTitle = NSAttributedString(
            string: group.name,
            attributes: [
                .font: NSFont.menuFont(ofSize: 11),
                .foregroundColor: NSColor(hex: group.color) ?? NSColor.secondaryLabelColor
            ]
        )
        return item
    }

    private func menuItem(for server: LocalServer) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.attributedTitle = serverMenuTitle(server)
        item.image = statusImage(isActive: server.isActive)
        item.submenu = submenu(for: server)
        return item
    }

    private func refreshMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        item.view = RefreshMenuItemView(target: self, action: #selector(refreshNow))
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

            let kill = NSMenuItem(title: "Kill", action: #selector(kill(_:)), keyEquivalent: "")
            kill.target = self
            kill.representedObject = server.id
            submenu.addItem(kill)

            let killAndRemove = NSMenuItem(title: "Kill and Remove", action: #selector(killAndRemove(_:)), keyEquivalent: "")
            killAndRemove.target = self
            killAndRemove.representedObject = server.id
            submenu.addItem(killAndRemove)
        } else {
            let pin = pinMenuItem(for: server)
            submenu.addItem(pin)

            let start = NSMenuItem(title: "Start", action: #selector(start(_:)), keyEquivalent: "")
            start.target = self
            start.representedObject = server.id
            start.isEnabled = server.startCommand != nil
            submenu.addItem(start)

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
        scheduleRefresh()
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

    @objc private func start(_ sender: NSMenuItem) {
        guard let server = server(for: sender), let startCommand = server.startCommand else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", startCommand]
        if let workingDirectory = server.workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }
        try? process.run()
        Task { await refresh() }
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

private final class RefreshMenuItemView: NSView {
    private weak var target: AnyObject?
    private let action: Selector
    private var isHovered = false {
        didSet { needsDisplay = true }
    }

    init(target: AnyObject, action: Selector) {
        self.target = target
        self.action = action
        super.init(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if isHovered {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 1), xRadius: 5, yRadius: 5).fill()
        }

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuFont(ofSize: 0),
            .foregroundColor: isHovered ? NSColor.selectedMenuItemTextColor : NSColor.labelColor
        ]
        let shortcutAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuFont(ofSize: 0),
            .foregroundColor: isHovered ? NSColor.selectedMenuItemTextColor : NSColor.secondaryLabelColor
        ]

        let title = NSAttributedString(string: "Refresh", attributes: titleAttributes)
        title.draw(at: NSPoint(x: 14, y: 4))

        let shortcut = NSAttributedString(string: "⌘R", attributes: shortcutAttributes)
        shortcut.draw(at: NSPoint(x: bounds.width - shortcut.size().width - 14, y: 4))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    override func mouseDown(with event: NSEvent) {
        _ = target?.perform(action, with: nil)
    }
}

extension StatusBarController: NSMenuDelegate {
    nonisolated func menuWillOpen(_ menu: NSMenu) {
        Task { @MainActor in
            self.scheduleRefresh()
        }
    }
}

private extension NSColor {
    convenience init?(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6 else { return nil }

        let scanner = Scanner(string: value)
        var rgb: UInt64 = 0
        guard scanner.scanHexInt64(&rgb) else { return nil }

        self.init(
            srgbRed: CGFloat((rgb & 0xFF0000) >> 16) / 255,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255,
            blue: CGFloat(rgb & 0x0000FF) / 255,
            alpha: 1
        )
    }
}
