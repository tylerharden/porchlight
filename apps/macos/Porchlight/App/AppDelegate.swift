import AppKit
import Sparkle

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static var sharedDelegate: AppDelegate?
    private let settings = AppSettings()
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    private lazy var mainWindowController = SettingsWindowController(settings: settings, updaterController: updaterController)
    private var statusBarController: StatusBarController?
    private var settingsObserver: NSObjectProtocol?

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
        statusBarController = StatusBarController(mainWindowController: mainWindowController, settings: settings)
        settingsObserver = NotificationCenter.default.addObserver(
            forName: AppSettings.didChangeNotification,
            object: settings,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.applyActivationPolicy() }
        }
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

        let checkForUpdates = NSMenuItem(
            title: Strings.About.checkForUpdates,
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        checkForUpdates.target = updaterController
        appMenu.addItem(checkForUpdates)

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

    private func applyActivationPolicy() {
        if settings.hideDockIcon && !mainWindowController.isWindowVisible {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }
    }
}
