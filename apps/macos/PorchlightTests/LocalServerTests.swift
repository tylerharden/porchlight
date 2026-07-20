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
    func testLocationTextFallsBackToWorkingDirectoryThenUnknown() {
        let serverWithWorkingDirectory = server(id: "a", port: 3000, group: nil, workingDirectory: "/tmp/app")
        let serverWithoutDirectory = server(id: "b", port: 8000, group: nil)

        XCTAssertEqual(serverWithWorkingDirectory.locationText, "/tmp/app")
        XCTAssertEqual(serverWithoutDirectory.locationText, "Unknown location")
    }

    @MainActor
    func testResolvedStartCommandUsesExplicitCommandFirst() {
        let server = server(
            id: "localhost:3000",
            port: 3000,
            group: nil,
            command: "npm run dev",
            startCommand: "pnpm dev"
        )

        XCTAssertEqual(server.resolvedStartCommand, "pnpm dev")
    }

    @MainActor
    func testResolvedStartCommandFallsBackToTrimmedCommand() {
        let server = server(id: "localhost:3000", port: 3000, group: nil, command: "  npm run dev  ")

        XCTAssertEqual(server.resolvedStartCommand, "npm run dev")
    }

    @MainActor
    func testResolvedStartCommandIgnoresBlankAndLiveServerCodeHelperCommands() {
        let blankCommand = server(id: "blank", port: 3000, group: nil, command: "   ")
        let liveServerCodeHelper = server(
            id: "live-server",
            port: 5500,
            group: nil,
            serverType: "Live Server",
            command: "/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper"
        )

        XCTAssertNil(blankCommand.resolvedStartCommand)
        XCTAssertNil(liveServerCodeHelper.resolvedStartCommand)
    }

    @MainActor
    func testLastSeenDateDecodesFractionalSeconds() {
        let server = server(
            id: "localhost:3000",
            port: 3000,
            group: nil,
            lastSeenAt: "2026-07-20T10:11:12.345Z"
        )

        XCTAssertNotNil(server.lastSeenDate)
    }

    @MainActor
    func testCanOpenInXcodeDetectsProjectOrWorkspace() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let project = directory.appendingPathComponent("Porchlight.xcodeproj", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        let server = server(id: "localhost:3000", port: 3000, group: nil, workingDirectory: directory.path)

        XCTAssertTrue(server.canOpenInXcode)
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
    private func server(
        id: String,
        port: Int,
        group: ServerGroupMatch?,
        serverType: String = "Node",
        command: String = "npm run dev",
        workingDirectory: String? = nil,
        startCommand: String? = nil,
        lastSeenAt: String? = nil
    ) -> LocalServer {
        LocalServer(
            id: id,
            port: port,
            pid: port,
            status: .active,
            processName: "node",
            serverType: serverType,
            icon: nil,
            group: group,
            command: command,
            workingDirectory: workingDirectory,
            displayDirectory: nil,
            url: "http://localhost:\(port)",
            pinned: false,
            lastSeenAt: lastSeenAt,
            startCommand: startCommand
        )
    }
}
