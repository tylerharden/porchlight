import XCTest
@testable import Porchlight

final class PorchlightLinksTests: XCTestCase {
    @MainActor
    func testProductLinksUseExpectedGitHubHost() {
        let links = [
            PorchlightLinks.repository,
            PorchlightLinks.issues,
            PorchlightLinks.termsOfUse,
            PorchlightLinks.privacyPolicy,
            PorchlightLinks.readme
        ]

        for link in links {
            XCTAssertEqual(link.scheme, "https")
            XCTAssertEqual(link.host, "github.com")
            XCTAssertTrue(link.path.hasPrefix("/tylerharden/porchlight"))
        }
    }

    @MainActor
    func testProductLinksPointToExpectedResources() {
        XCTAssertEqual(PorchlightLinks.repository.path, "/tylerharden/porchlight")
        XCTAssertEqual(PorchlightLinks.issues.path, "/tylerharden/porchlight/issues/new")
        XCTAssertEqual(PorchlightLinks.termsOfUse.path, "/tylerharden/porchlight/blob/main/TERMS_OF_USE.md")
        XCTAssertEqual(PorchlightLinks.privacyPolicy.path, "/tylerharden/porchlight/blob/main/PRIVACY_POLICY.md")
        XCTAssertEqual(PorchlightLinks.readme.fragment, "readme")
    }
}
