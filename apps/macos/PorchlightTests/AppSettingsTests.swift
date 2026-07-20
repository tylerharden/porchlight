import XCTest
@testable import Porchlight

final class AppSettingsTests: XCTestCase {
    @MainActor
    func testDefaultsUseExpectedInitialValues() {
        let defaults = isolatedDefaults()

        let settings = AppSettings(defaults: defaults)

        XCTAssertTrue(settings.autoRefresh)
        XCTAssertEqual(settings.refreshInterval, 2)
        XCTAssertTrue(settings.hideDockIcon)
        XCTAssertFalse(settings.hideMenuIconWhenEmpty)
        XCTAssertTrue(settings.showAutomaticGroups)
        XCTAssertTrue(settings.showAppServices)
    }

    @MainActor
    func testSettingsLoadPersistedValues() {
        let defaults = isolatedDefaults()
        defaults.set(false, forKey: "autoRefresh")
        defaults.set(10.0, forKey: "refreshInterval")
        defaults.set(false, forKey: "hideDockIcon")
        defaults.set(true, forKey: "hideMenuIconWhenEmpty")
        defaults.set(false, forKey: "showAutomaticGroups")
        defaults.set(false, forKey: "showAppServices")

        let settings = AppSettings(defaults: defaults)

        XCTAssertFalse(settings.autoRefresh)
        XCTAssertEqual(settings.refreshInterval, 10)
        XCTAssertFalse(settings.hideDockIcon)
        XCTAssertTrue(settings.hideMenuIconWhenEmpty)
        XCTAssertFalse(settings.showAutomaticGroups)
        XCTAssertFalse(settings.showAppServices)
    }

    @MainActor
    func testSettingsPersistToInjectedDefaults() {
        let defaults = isolatedDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.autoRefresh = false
        settings.refreshInterval = 5
        settings.hideDockIcon = false
        settings.hideMenuIconWhenEmpty = true

        XCTAssertEqual(defaults.object(forKey: "autoRefresh") as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: "refreshInterval") as? Double, 5)
        XCTAssertEqual(defaults.object(forKey: "hideDockIcon") as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: "hideMenuIconWhenEmpty") as? Bool, true)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "dev.tylerharden.porchlight.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
