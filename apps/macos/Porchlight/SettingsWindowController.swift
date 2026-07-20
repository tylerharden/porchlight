import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let settings: AppSettings
    private lazy var viewModel = ServerListViewModel(settings: settings)
    private var window: NSWindow?

    var isWindowVisible: Bool {
        window?.isVisible == true
    }

    init(settings: AppSettings) {
        self.settings = settings
        super.init()
    }

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
        window.contentView = NSHostingView(rootView: SettingsView(viewModel: viewModel, settings: settings) { [weak window] title in
            window?.title = title
        })
        window.isReleasedWhenClosed = false
        return window
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        if settings.hideDockIcon {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
