import XCTest
@testable import Porchlight

final class LocalServerTests: XCTestCase {
    @MainActor
    func testDecodingDefaultsHiddenToFalse() throws {
        let data = Data("""
        {
          "id": "localhost:3000",
          "port": 3000,
          "pid": 1234,
          "status": "active",
          "process_name": "node",
          "server_type": "Next.js",
          "command": "npm run dev",
          "url": "http://localhost:3000",
          "pinned": false
        }
        """.utf8)

        let server = try JSONDecoder().decode(LocalServer.self, from: data)

        let isHidden = server.hidden
        XCTAssertFalse(isHidden)
    }

    @MainActor
    func testLocationTextPrefersDisplayDirectory() {
        let server = LocalServer(
            id: "localhost:3000",
            port: 3000,
            pid: 1234,
            status: .active,
            processName: "node",
            serverType: "Next.js",
            icon: nil,
            group: nil,
            command: "npm run dev",
            workingDirectory: "/tmp/porchlight",
            displayDirectory: "~/Developer/porchlight",
            url: "http://localhost:3000",
            pinned: false,
            lastSeenAt: nil,
            startCommand: nil
        )

        let locationText = server.locationText
        XCTAssertEqual(locationText, "~/Developer/porchlight")
    }

    @MainActor
    func testGroupedSectionsKeepsGroupsTogetherAndUngroupedLast() {
        let group = ServerGroupMatch(
            id: "frontend",
            name: "Frontend",
            kind: "Next.js",
            role: "Frontend",
            color: "#007AFF",
            icon: nil,
            confidence: 1,
            source: "test"
        )
        let groupedA = server(id: "a", port: 3000, group: group)
        let ungrouped = server(id: "b", port: 8000, group: nil)
        let groupedB = server(id: "c", port: 5173, group: group)

        let sections = [groupedA, ungrouped, groupedB].groupedSections()

        let sectionIDs = sections.map { $0.id }
        let groupedServerIDs = sections[0].servers.map { $0.id }
        let ungroupedServerIDs = sections[1].servers.map { $0.id }

        XCTAssertEqual(sectionIDs, ["frontend", "ungrouped"])
        XCTAssertEqual(groupedServerIDs, ["a", "c"])
        XCTAssertEqual(ungroupedServerIDs, ["b"])
    }

    @MainActor
    private func server(id: String, port: Int, group: ServerGroupMatch?) -> LocalServer {
        LocalServer(
            id: id,
            port: port,
            pid: port,
            status: .active,
            processName: "node",
            serverType: "Node",
            icon: nil,
            group: group,
            command: "npm run dev",
            workingDirectory: nil,
            displayDirectory: nil,
            url: "http://localhost:\(port)",
            pinned: false,
            lastSeenAt: nil,
            startCommand: nil
        )
    }
}
