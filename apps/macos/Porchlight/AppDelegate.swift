import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static var sharedDelegate: AppDelegate?
    private let mainWindowController = SettingsWindowController()
    private var statusBarController: StatusBarController?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        sharedDelegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        delegate.installMainMenu()
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.applicationIconImage = PorchlightAppIcon.image
        statusBarController = StatusBarController(mainWindowController: mainWindowController)
        mainWindowController.show()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        mainWindowController.show()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()

        let show = NSMenuItem(title: "Show Porchlight", action: #selector(showPorchlight), keyEquivalent: "0")
        show.target = self
        appMenu.addItem(show)

        appMenu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Porchlight", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quit)

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }

    @objc private func showPorchlight() {
        mainWindowController.show()
    }
}
