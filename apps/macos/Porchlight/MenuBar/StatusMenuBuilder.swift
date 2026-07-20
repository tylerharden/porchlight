import AppKit

@MainActor
struct StatusMenuBuilder {
    struct Actions {
        let refresh: Selector
        let openPorchlight: Selector
        let quit: Selector
        let openAddress: Selector
        let openInFinder: Selector
        let openInVSCode: Selector
        let openInXcode: Selector
        let copyCommand: Selector
        let startServer: Selector
        let killServer: Selector
        let killAll: Selector
        let killAndRemove: Selector
        let remove: Selector
        let hide: Selector
        let togglePin: Selector
    }

    let target: AnyObject
    let delegate: NSMenuDelegate?
    let actions: Actions
    let showGroupIcons: Bool

    func menu(
        servers: [LocalServer],
        startingServerIDs: Set<String>,
        killingServerIDs: Set<String>,
        error: String? = nil
    ) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = delegate

        populate(
            menu,
            servers: servers,
            startingServerIDs: startingServerIDs,
            killingServerIDs: killingServerIDs,
            error: error
        )
        return menu
    }

    func populate(
        _ menu: NSMenu,
        servers: [LocalServer],
        startingServerIDs: Set<String>,
        killingServerIDs: Set<String>,
        error: String? = nil
    ) {
        menu.removeAllItems()

        if let error {
            addDisabledItem(Strings.StatusMenu.cliFailed, to: menu)
            addDisabledItem(error, to: menu)
        } else if servers.isEmpty {
            addDisabledItem(Strings.StatusMenu.noServersRunning, to: menu)
        } else {
            addServerItems(
                to: menu,
                servers: servers,
                startingServerIDs: startingServerIDs,
                killingServerIDs: killingServerIDs
            )
        }

        menu.addItem(.separator())

        menu.addItem(refreshMenuItem())
        menu.addItem(killAllMenuItem(isEnabled: servers.contains { $0.isActive }))

        menu.addItem(.separator())

        menu.addItem(menuItem(title: Strings.StatusMenu.openPorchlight, action: actions.openPorchlight))
        menu.addItem(menuItem(title: Strings.StatusMenu.quitPorchlight, action: actions.quit, keyEquivalent: "q"))
    }

    private func addServerItems(
        to menu: NSMenu,
        servers: [LocalServer],
        startingServerIDs: Set<String>,
        killingServerIDs: Set<String>
    ) {
        var addedSection = false

        for section in servers.groupedSections() {
            if addedSection {
                menu.addItem(.separator())
            }
            if let group = section.group {
                menu.addItem(groupHeaderItem(for: group))
            }
            section.servers.forEach {
                menu.addItem(menuItem(for: $0, startingServerIDs: startingServerIDs, killingServerIDs: killingServerIDs))
            }
            addedSection = true
        }
    }

    private func addDisabledItem(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func groupHeaderItem(for group: ServerGroupMatch) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.isEnabled = false
        if showGroupIcons {
            item.image = groupIconImage(group.icon)
        }
        item.attributedTitle = NSAttributedString(
            string: group.name,
            attributes: [
                .font: NSFont.menuFont(ofSize: 11),
                .foregroundColor: NSColor(hex: group.color ?? "") ?? NSColor.secondaryLabelColor
            ]
        )
        return item
    }

    private func menuItem(
        for server: LocalServer,
        startingServerIDs: Set<String>,
        killingServerIDs: Set<String>
    ) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")

        if startingServerIDs.contains(server.id) || killingServerIDs.contains(server.id) {
            item.view = ServerMenuItemView(server: server)
            return item
        }

        item.attributedTitle = serverMenuTitle(server)
        item.image = statusImage(isActive: server.isActive)
        item.submenu = submenu(for: server, startingServerIDs: startingServerIDs, killingServerIDs: killingServerIDs)
        return item
    }

    private func refreshMenuItem() -> NSMenuItem {
        menuItem(title: Strings.StatusMenu.refresh, action: actions.refresh, keyEquivalent: "r")
    }

    private func killAllMenuItem(isEnabled: Bool) -> NSMenuItem {
        let item = menuItem(title: Strings.StatusMenu.killAll, action: actions.killAll)
        item.isEnabled = isEnabled
        return item
    }

    private func submenu(
        for server: LocalServer,
        startingServerIDs: Set<String>,
        killingServerIDs: Set<String>
    ) -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        addDisabledItem(server.locationText, to: submenu)
        submenu.addItem(.separator())

        let openAddress = menuItem(title: displayURL(server.url), action: actions.openAddress, representedObject: server.id)
        openAddress.image = serverIconImage(server)
        submenu.addItem(openAddress)

        if server.workingDirectory != nil {
            submenu.addItem(menuItem(title: Strings.StatusMenu.openInFinder, action: actions.openInFinder, representedObject: server.id))

            let openInApp = NSMenuItem(title: Strings.ServerDetail.openInApp, action: nil, keyEquivalent: "")
            openInApp.submenu = openInAppSubmenu(for: server)
            submenu.addItem(openInApp)
        }

        submenu.addItem(.separator())
        addDisabledItem("pid \(server.pid) • \(server.processName)", to: submenu)

        let command = NSMenuItem(title: Strings.StatusMenu.command, action: nil, keyEquivalent: "")
        command.submenu = commandSubmenu(for: server)
        submenu.addItem(command)

        submenu.addItem(.separator())

        submenu.addItem(pinMenuItem(for: server))
        if server.isActive {
            submenu.addItem(killMenuItem(for: server, killingServerIDs: killingServerIDs))
            submenu.addItem(menuItem(title: Strings.StatusMenu.killAndRemove, action: actions.killAndRemove, representedObject: server.id))
        } else {
            submenu.addItem(startMenuItem(for: server, startingServerIDs: startingServerIDs))
            submenu.addItem(menuItem(title: Strings.ServerDetail.remove, action: actions.remove, representedObject: server.id))
        }
        submenu.addItem(hideMenuItem(for: server))

        return submenu
    }

    private func pinMenuItem(for server: LocalServer) -> NSMenuItem {
        menuItem(title: server.pinned ? Strings.ServerDetail.unpin : Strings.ServerDetail.pin, action: actions.togglePin, representedObject: server.id)
    }

    private func hideMenuItem(for server: LocalServer) -> NSMenuItem {
        menuItem(title: Strings.ServerDetail.hide, action: actions.hide, representedObject: server.id)
    }

    private func startMenuItem(for server: LocalServer, startingServerIDs: Set<String>) -> NSMenuItem {
        let item = menuItem(title: Strings.StatusMenu.start, action: actions.startServer, representedObject: server.id)
        item.isEnabled = server.resolvedStartCommand != nil && !startingServerIDs.contains(server.id)
        return item
    }

    private func killMenuItem(for server: LocalServer, killingServerIDs: Set<String>) -> NSMenuItem {
        let item = menuItem(title: Strings.StatusMenu.kill, action: actions.killServer, representedObject: server.id)
        item.isEnabled = !killingServerIDs.contains(server.id)
        return item
    }

    private func openInAppSubmenu(for server: LocalServer) -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        submenu.addItem(menuItem(title: Strings.ServerDetail.visualStudioCode, action: actions.openInVSCode, representedObject: server.id))

        let xcode = menuItem(title: Strings.ServerDetail.xcode, action: actions.openInXcode, representedObject: server.id)
        xcode.isEnabled = canOpenInXcode(server)
        submenu.addItem(xcode)

        return submenu
    }

    private func commandSubmenu(for server: LocalServer) -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        addDisabledItem(shortened(server.command, limit: 72), to: submenu)
        submenu.addItem(menuItem(title: Strings.StatusMenu.copyCommand, action: actions.copyCommand, representedObject: server.id))

        return submenu
    }

    private func menuItem(
        title: String,
        action: Selector,
        keyEquivalent: String = "",
        representedObject: Any? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = target
        item.representedObject = representedObject
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

        if server.pinned {
            title.append(NSAttributedString(string: "  "))
            title.append(NSAttributedString(
                string: "📌",
                attributes: [
                    .font: NSFont.menuFont(ofSize: 0)
                ]
            ))
        }

        return title
    }

    private func canOpenInXcode(_ server: LocalServer) -> Bool {
        guard let workingDirectory = server.workingDirectory else { return false }
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: workingDirectory)) ?? []
        return contents.contains { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }
    }

    private func shortened(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit - 3)) + "..."
    }

    private func displayURL(_ value: String) -> String {
        guard let url = URL(string: value), let host = url.host else { return value }

        if let port = url.port {
            return "\(host):\(port)"
        }

        return host
    }
}
