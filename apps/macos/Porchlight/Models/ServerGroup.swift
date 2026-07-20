import AppKit
import SwiftUI

struct ServerGroupsDocument: Codable {
    var groups: [ServerGroup]

    enum CodingKeys: String, CodingKey {
        case groups
    }

    init(groups: [ServerGroup]) {
        self.groups = groups
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        groups = try container.decodeIfPresent([ServerGroup].self, forKey: .groups) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(groups, forKey: .groups)
    }
}

struct GroupSummaryDocument: Decodable {
    let groups: [GroupSummary]
}

struct GroupSummary: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let source: String
    let manual: Bool
    let kind: String?
    let role: String?
    let reason: String?
    let color: String?
    let icon: String?
    let activeServerCount: Int
    let recentServerCount: Int
    let activeCount: Int
    let hidden: Bool
    let firstSeenAt: String?
    let lastSeenAt: String?
    let ports: [Int]
    let paths: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case source
        case manual
        case kind
        case role
        case reason
        case color
        case icon
        case activeServerCount = "active_server_count"
        case recentServerCount = "recent_server_count"
        case activeCount = "active_count"
        case hidden
        case firstSeenAt = "first_seen_at"
        case lastSeenAt = "last_seen_at"
        case ports
        case paths
    }

    var firstSeenText: String? {
        relativeText(for: firstSeenAt)
    }

    var lastSeenText: String? {
        relativeText(for: lastSeenAt)
    }

    private func relativeText(for timestamp: String?) -> String? {
        guard let timestamp else { return nil }
        let date = ISO8601DateFormatter.groupSummary.date(from: timestamp)
            ?? ISO8601DateFormatter.groupSummaryWithFractionalSeconds.date(from: timestamp)
        guard let date else { return timestamp }
        return RelativeDateTimeFormatter.groupSummary.localizedString(for: date, relativeTo: Date())
    }
}

struct ServerSection: Identifiable {
    let group: ServerGroupMatch?
    var servers: [LocalServer]

    var id: String {
        group?.id ?? "ungrouped"
    }
}

extension [LocalServer] {
    func groupedSections() -> [ServerSection] {
        var sections: [ServerSection] = []
        var ungroupedServers: [LocalServer] = []

        for server in self {
            guard let group = server.group else {
                ungroupedServers.append(server)
                continue
            }

            if let index = sections.firstIndex(where: { $0.id == group.id }) {
                sections[index].servers.append(server)
            } else {
                sections.append(ServerSection(group: group, servers: [server]))
            }
        }

        if !ungroupedServers.isEmpty {
            sections.append(ServerSection(group: nil, servers: ungroupedServers))
        }

        return sections.map { section in
            var section = section
            section.servers.sort { a, b in
                if a.pinned == b.pinned {
                    return false
                }
                return a.pinned
            }
            return section
        }
    }
}

struct ServerGroup: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var color: String
    var icon: String?
    var commandContains: [String]
    var workingDirectories: [String]
    var priority: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case color
        case icon
        case commandContains = "command_contains"
        case workingDirectories = "working_directories"
        case priority
    }

    static func empty() -> ServerGroup {
        ServerGroup(
            id: UUID().uuidString,
            name: "New Group",
            color: "#34C759",
            icon: nil,
            commandContains: [],
            workingDirectories: [],
            priority: 100
        )
    }
}

@MainActor
@Observable
final class ServerGroupStore {
    static let didChangeNotification = Notification.Name("PorchlightServerGroupsDidChange")

    private let cli = PorchlightCLI()

    var groups: [ServerGroup] = []
    var summaries: [GroupSummary] = []
    var errorMessage: String?

    var hasLoadedGroups = false

    var isLoadingInitialGroups: Bool {
        !hasLoadedGroups && errorMessage == nil
    }

    func load() async {
        do {
            groups = try await cli.listGroups()
            summaries = try await cli.groupSummaries()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        if !hasLoadedGroups {
            hasLoadedGroups = true
        }
    }

    func addGroup() -> ServerGroup.ID {
        let group = ServerGroup.empty()
        groups.append(group)
        save()
        return group.id
    }

    func deleteGroup(id: ServerGroup.ID) {
        groups.removeAll { $0.id == id }
        save()
    }

    func promoteGroup(id: GroupSummary.ID) async {
        do {
            try await cli.promoteGroup(id: id)
            groups = try await cli.listGroups()
            try await reloadSummariesAndNotify()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setGroupHidden(id: GroupSummary.ID, hidden: Bool) async {
        do {
            if hidden {
                try await cli.hideGroup(id: id)
            } else {
                try await cli.unhideGroup(id: id)
            }
            try await reloadSummariesAndNotify()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func binding<Value>(for id: ServerGroup.ID, keyPath: WritableKeyPath<ServerGroup, Value>) -> Binding<Value>? {
        guard let initialValue = groups.first(where: { $0.id == id })?[keyPath: keyPath] else { return nil }

        return Binding(
            get: {
                self.groups.first(where: { $0.id == id })?[keyPath: keyPath] ?? initialValue
            },
            set: { newValue in
                guard let index = self.groups.firstIndex(where: { $0.id == id }) else { return }
                self.groups[index][keyPath: keyPath] = newValue
                self.save()
            }
        )
    }

    func addCommand(_ command: String, to id: ServerGroup.ID) {
        updateList(\.commandContains, for: id) { values in
            values.append(command.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    func removeCommand(_ command: String, from id: ServerGroup.ID) {
        updateList(\.commandContains, for: id) { values in
            values.removeAll { $0 == command }
        }
    }

    func addWorkingDirectory(_ path: String, to id: ServerGroup.ID) {
        updateList(\.workingDirectories, for: id) { values in
            values.append(path.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    func removeWorkingDirectory(_ path: String, from id: ServerGroup.ID) {
        updateList(\.workingDirectories, for: id) { values in
            values.removeAll { $0 == path }
        }
    }

    private func updateList(
        _ keyPath: WritableKeyPath<ServerGroup, [String]>,
        for id: ServerGroup.ID,
        update: (inout [String]) -> Void
    ) {
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return }
        update(&groups[index][keyPath: keyPath])
        groups[index][keyPath: keyPath].removeAll { $0.isEmpty }
        save()
    }

    private func save() {
        let groups = groups
        let cli = cli
        Task {
            do {
                try await cli.replaceGroups(groups)
                try await reloadSummariesAndNotify()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func reloadSummariesAndNotify() async throws {
        summaries = try await cli.groupSummaries()
        errorMessage = nil
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }
}

extension Color {
    init(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: value)
        var rgb: UInt64 = 0

        guard value.count == 6, scanner.scanHexInt64(&rgb) else {
            self.init(nsColor: .systemGray)
            return
        }

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255,
            green: Double((rgb & 0x00FF00) >> 8) / 255,
            blue: Double(rgb & 0x0000FF) / 255
        )
    }

    var hexString: String {
        let color = NSColor(self).usingColorSpace(.sRGB) ?? .systemGreen
        return String(
            format: "#%02X%02X%02X",
            Int(round(color.redComponent * 255)),
            Int(round(color.greenComponent * 255)),
            Int(round(color.blueComponent * 255))
        )
    }
}

private extension ISO8601DateFormatter {
    static let groupSummary: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let groupSummaryWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private extension RelativeDateTimeFormatter {
    static let groupSummary: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}
