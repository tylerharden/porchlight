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
    let icon: String?
    let group: ServerGroupMatch?
    let command: String
    let workingDirectory: String?
    let displayDirectory: String?
    let url: String
    let pinned: Bool
    let hidden: Bool
    let lastSeenAt: String?
    let startCommand: String?

    enum CodingKeys: String, CodingKey {
        case id
        case port
        case pid
        case status
        case processName = "process_name"
        case serverType = "server_type"
        case icon
        case group
        case command
        case workingDirectory = "working_directory"
        case displayDirectory = "display_directory"
        case url
        case pinned
        case hidden
        case lastSeenAt = "last_seen_at"
        case startCommand = "start_command"
    }

    init(
        id: String,
        port: Int,
        pid: Int,
        status: ServerStatus,
        processName: String,
        serverType: String,
        icon: String?,
        group: ServerGroupMatch?,
        command: String,
        workingDirectory: String?,
        displayDirectory: String?,
        url: String,
        pinned: Bool,
        hidden: Bool = false,
        lastSeenAt: String?,
        startCommand: String?
    ) {
        self.id = id
        self.port = port
        self.pid = pid
        self.status = status
        self.processName = processName
        self.serverType = serverType
        self.icon = icon
        self.group = group
        self.command = command
        self.workingDirectory = workingDirectory
        self.displayDirectory = displayDirectory
        self.url = url
        self.pinned = pinned
        self.hidden = hidden
        self.lastSeenAt = lastSeenAt
        self.startCommand = startCommand
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        port = try container.decode(Int.self, forKey: .port)
        pid = try container.decode(Int.self, forKey: .pid)
        status = try container.decode(ServerStatus.self, forKey: .status)
        processName = try container.decode(String.self, forKey: .processName)
        serverType = try container.decode(String.self, forKey: .serverType)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        group = try container.decodeIfPresent(ServerGroupMatch.self, forKey: .group)
        command = try container.decode(String.self, forKey: .command)
        workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
        displayDirectory = try container.decodeIfPresent(String.self, forKey: .displayDirectory)
        url = try container.decode(String.self, forKey: .url)
        pinned = try container.decode(Bool.self, forKey: .pinned)
        hidden = try container.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
        lastSeenAt = try container.decodeIfPresent(String.self, forKey: .lastSeenAt)
        startCommand = try container.decodeIfPresent(String.self, forKey: .startCommand)
    }

    var locationText: String {
        displayDirectory ?? workingDirectory ?? "Unknown location"
    }

    var isActive: Bool {
        status == .active
    }

    var resolvedStartCommand: String? {
        if serverType == "Live Server" && command.contains("Code Helper") {
            return nil
        }

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

struct ServerGroupMatch: Codable, Hashable {
    let id: String
    let name: String
    let kind: String
    let role: String
    let color: String?
    let icon: String?
    let confidence: Double
    let source: String
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
