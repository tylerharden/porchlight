import Foundation
import ServiceManagement

@MainActor
@Observable
final class AppSettings {
    static let didChangeNotification = Notification.Name("PorchlightAppSettingsDidChange")

    var autoRefresh: Bool {
        didSet { persistAndNotify("autoRefresh", autoRefresh) }
    }

    var refreshInterval: Double {
        didSet { persistAndNotify("refreshInterval", refreshInterval) }
    }

    var launchAtLogin: Bool {
        didSet { updateLaunchAtLogin() }
    }

    var hideDockIcon: Bool {
        didSet { persistAndNotify("hideDockIcon", hideDockIcon) }
    }

    var hideMenuIconWhenEmpty: Bool {
        didSet { persistAndNotify("hideMenuIconWhenEmpty", hideMenuIconWhenEmpty) }
    }

    var showAutomaticGroups: Bool {
        didSet {
            persistAndNotify("showAutomaticGroups", showAutomaticGroups)
            persistAutomaticGroupsToCLI()
        }
    }

    var errorMessage: String?

    init(defaults: UserDefaults = .standard) {
        autoRefresh = defaults.object(forKey: "autoRefresh") as? Bool ?? true
        refreshInterval = defaults.object(forKey: "refreshInterval") as? Double ?? 2
        hideDockIcon = defaults.object(forKey: "hideDockIcon") as? Bool ?? true
        hideMenuIconWhenEmpty = defaults.object(forKey: "hideMenuIconWhenEmpty") as? Bool ?? false
        showAutomaticGroups = defaults.object(forKey: "showAutomaticGroups") as? Bool ?? true
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func persistAndNotify(_ key: String, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
        notifyChanged()
    }

    private func persistAndNotify(_ key: String, _ value: Double) {
        UserDefaults.standard.set(value, forKey: key)
        notifyChanged()
    }

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        notifyChanged()
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    private func persistAutomaticGroupsToCLI() {
        let showAutomaticGroups = showAutomaticGroups
        Task {
            do {
                try await PorchlightCLI().setAutomaticGroups(showAutomaticGroups)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
