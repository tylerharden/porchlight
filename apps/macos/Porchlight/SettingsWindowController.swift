import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let viewModel = ServerListViewModel()
    private var window: NSWindow?

    func show() {
        NSApp.setActivationPolicy(.regular)

        if window == nil {
            window = makeWindow()
        }

        Task { await viewModel.refresh() }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 460),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Servers"
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unifiedCompact
        window.center()
        window.delegate = self
        window.contentView = NSHostingView(rootView: SettingsView(viewModel: viewModel) { [weak window] title in
            window?.title = title
        })
        window.isReleasedWhenClosed = false
        return window
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        NSApp.setActivationPolicy(.accessory)
    }
}
