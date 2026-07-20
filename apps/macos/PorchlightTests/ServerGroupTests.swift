import SwiftUI
import XCTest
@testable import Porchlight

final class ServerGroupTests: XCTestCase {
    @MainActor
    func testServerGroupsDocumentDefaultsMissingGroupsToEmptyArray() throws {
        let data = Data("{}".utf8)

        let document = try JSONDecoder().decode(ServerGroupsDocument.self, from: data)

        XCTAssertEqual(document.groups, [])
    }

    @MainActor
    func testServerGroupUsesSnakeCaseKeys() throws {
        let data = Data("""
        {
          "id": "frontend",
          "name": "Frontend",
          "color": "#007AFF",
          "icon": "globe",
          "command_contains": ["next dev", "vite"],
          "working_directories": ["~/Developer/app"],
          "priority": 50
        }
        """.utf8)

        let group = try JSONDecoder().decode(ServerGroup.self, from: data)

        XCTAssertEqual(group.id, "frontend")
        XCTAssertEqual(group.commandContains, ["next dev", "vite"])
        XCTAssertEqual(group.workingDirectories, ["~/Developer/app"])
    }

    @MainActor
    func testGroupSummaryDecodesCountsAndDefaultsOptionalDates() throws {
        let data = Data("""
        {
          "id": "frontend",
          "name": "Frontend",
          "source": "automatic",
          "manual": false,
          "kind": "Next.js",
          "role": "Frontend",
          "reason": "command match",
          "color": "#007AFF",
          "icon": "globe",
          "active_server_count": 2,
          "recent_server_count": 1,
          "active_count": 3,
          "hidden": true,
          "ports": [3000, 5173],
          "paths": ["~/Developer/app"]
        }
        """.utf8)

        let summary = try JSONDecoder().decode(GroupSummary.self, from: data)

        XCTAssertEqual(summary.activeServerCount, 2)
        XCTAssertEqual(summary.recentServerCount, 1)
        XCTAssertEqual(summary.activeCount, 3)
        XCTAssertTrue(summary.hidden)
        XCTAssertNil(summary.firstSeenText)
        XCTAssertNil(summary.lastSeenText)
    }

    @MainActor
    func testInvalidHexColorFallsBackToGray() {
        let gray = Color(hex: "not-a-color").hexString

        XCTAssertEqual(gray, Color(nsColor: .systemGray).hexString)
    }
}
