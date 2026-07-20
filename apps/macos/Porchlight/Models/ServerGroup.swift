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
    var groups: [ServerGroup] = []
    var errorMessage: String?

    func load() async {
        do {
            groups = try await PorchlightCLI().listGroups()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
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

    func binding<Value>(for id: ServerGroup.ID, keyPath: WritableKeyPath<ServerGroup, Value>) -> Binding<Value>? {
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return nil }

        return Binding(
            get: { self.groups[index][keyPath: keyPath] },
            set: { newValue in
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
        Task {
            do {
                try await PorchlightCLI().replaceGroups(groups)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
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
