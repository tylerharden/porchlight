import Foundation
import ServiceManagement

@MainActor
@Observable
final class AppSettings {
    static let didChangeNotification = Notification.Name("PorchlightAppSettingsDidChange")
    private let defaults: UserDefaults
    private var isResetting = false

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
            persistCLISetting(showAutomaticGroups) { cli, value in
                try await cli.setAutomaticGroups(value)
            }
        }
    }

    var showAppServices: Bool {
        didSet {
            persistAndNotify("showAppServices", showAppServices)
            persistCLISetting(showAppServices) { cli, value in
                try await cli.setAppServices(value)
            }
        }
    }

    var errorMessage: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        autoRefresh = defaults.object(forKey: "autoRefresh") as? Bool ?? true
        refreshInterval = defaults.object(forKey: "refreshInterval") as? Double ?? 2
        hideDockIcon = defaults.object(forKey: "hideDockIcon") as? Bool ?? true
        hideMenuIconWhenEmpty = defaults.object(forKey: "hideMenuIconWhenEmpty") as? Bool ?? false
        showAutomaticGroups = defaults.object(forKey: "showAutomaticGroups") as? Bool ?? true
        showAppServices = defaults.object(forKey: "showAppServices") as? Bool ?? true
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func persistAndNotify(_ key: String, _ value: Bool) {
        guard !isResetting else { return }
        defaults.set(value, forKey: key)
        notifyChanged()
    }

    private func persistAndNotify(_ key: String, _ value: Double) {
        guard !isResetting else { return }
        defaults.set(value, forKey: key)
        notifyChanged()
    }

    private func updateLaunchAtLogin() {
        guard !isResetting else { return }

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

    private func persistCLISetting(
        _ value: Bool,
        update: @escaping (PorchlightCLI, Bool) async throws -> Void
    ) {
        guard !isResetting else { return }

        Task {
            do {
                try await update(PorchlightCLI(), value)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func resetToDefaults() async {
        do {
            try await PorchlightCLI().reset()
            try? await SMAppService.mainApp.unregister()

            isResetting = true
            autoRefresh = true
            refreshInterval = 2
            launchAtLogin = false
            hideDockIcon = true
            hideMenuIconWhenEmpty = false
            showAutomaticGroups = true
            showAppServices = true
            isResetting = false

            [
                "autoRefresh",
                "refreshInterval",
                "hideDockIcon",
                "hideMenuIconWhenEmpty",
                "showAutomaticGroups",
                "showAppServices",
            ].forEach { defaults.removeObject(forKey: $0) }

            errorMessage = nil
            notifyChanged()
        } catch {
            isResetting = false
            errorMessage = error.localizedDescription
            notifyChanged()
        }
    }
}
