import XCTest
@testable import Porchlight

final class BuildInfoTests: XCTestCase {
    @MainActor
    func testPorchlightCLIVersionIsWellFormed() {
        let version = BuildInfo.porchlightCLIVersion

        XCTAssertFalse(version.isEmpty, "BuildInfo.porchlightCLIVersion should never be empty")

        let components = version.split(separator: ".")
        XCTAssertGreaterThanOrEqual(
            components.count, 3,
            "expected a dotted version like 0.1.5, got \(version)"
        )
        XCTAssertTrue(
            components.allSatisfy { $0.allSatisfy(\.isNumber) },
            "expected all-numeric dotted components, got \(version)"
        )
    }
}
