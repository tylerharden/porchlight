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
}

enum ServerStatus: String, Decodable {
    case active
    case recent
    case stopped
    case unknown
}
