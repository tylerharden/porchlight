import Foundation

struct ServerListResponse: Decodable {
    let servers: [LocalServer]
}

struct LocalServer: Decodable, Identifiable, Hashable {
    let id: String
    let port: Int
    let pid: Int
    let status: ServerStatus
    let processName: String
    let serverType: String
    let group: ServerGroupMatch?
    let icon: String?
    let command: String
    let workingDirectory: String?
    let displayDirectory: String?
    let url: String
    let pinned: Bool
    let lastSeenAt: String?
    let startCommand: String?

    enum CodingKeys: String, CodingKey {
        case id
        case port
        case pid
        case status
        case processName = "process_name"
        case serverType = "server_type"
        case group
        case icon
        case command
        case workingDirectory = "working_directory"
        case displayDirectory = "display_directory"
        case url
        case pinned
        case lastSeenAt = "last_seen_at"
        case startCommand = "start_command"
    }

    var locationText: String {
        displayDirectory ?? workingDirectory ?? "Unknown location"
    }

    var isActive: Bool {
        status == .active
    }

    var resolvedStartCommand: String? {
        if let startCommand, !startCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return startCommand
        }

        let command = command.trimmingCharacters(in: .whitespacesAndNewlines)
        return command.isEmpty ? nil : command
    }

    var lastSeenDate: Date? {
        guard let lastSeenAt else { return nil }
        return ISO8601DateFormatter.porchlight.date(from: lastSeenAt)
            ?? ISO8601DateFormatter.porchlightWithFractionalSeconds.date(from: lastSeenAt)
    }

    var lastSeenText: String? {
        guard let lastSeenDate else { return lastSeenAt }
        return RelativeDateTimeFormatter.porchlight.localizedString(for: lastSeenDate, relativeTo: Date())
    }

    var canOpenInXcode: Bool {
        guard let workingDirectory else { return false }
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: workingDirectory)) ?? []
        return contents.contains { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }
    }
}

private extension ISO8601DateFormatter {
    static let porchlight: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let porchlightWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private extension RelativeDateTimeFormatter {
    static let porchlight: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}

enum ServerStatus: String, Decodable {
    case active
    case recent
    case stopped
    case unknown
}
