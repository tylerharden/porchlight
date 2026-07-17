import SwiftUI

struct ServerRowView: View {
    let server: LocalServer
    var isStarting = false

    var body: some View {
        HStack(spacing: 8) {
            if isStarting {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 12, height: 12)
            } else {
                Circle()
                    .fill(server.isActive ? Color.green : Color.gray.opacity(0.45))
                    .frame(width: 12, height: 12)
            }

            Text(verbatim: String(server.port))
                .font(.body)

            Text(server.serverType)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let group = server.group {
                GroupIconView(icon: server.icon ?? group.icon, color: group.color, size: 8)

                Text(group.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if server.icon != nil {
                GroupIconView(icon: server.icon, color: "#8E8E93", size: 8)
            }

            if server.pinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .opacity(server.isActive || isStarting ? 1 : 0.62)
    }
}

#Preview {
    VStack(spacing: 0) {
        ServerRowView(server: LocalServer(
            id: "1", port: 3000, pid: 1234, status: .active,
            processName: "node", serverType: "Next.js",
            group: ServerGroupMatch(id: "g1", name: "Frontend", color: "#007AFF", icon: nil),
            icon: nil,
            command: "next dev",
            workingDirectory: "/Users/tyler/Developer/myapp",
            displayDirectory: "~/Developer/myapp",
            url: "http://localhost:3000",
            pinned: true, lastSeenAt: nil, startCommand: "npm run dev"
        ))
        .padding(.horizontal)

        Divider()

        ServerRowView(server: LocalServer(
            id: "2", port: 8000, pid: 5678, status: .recent,
            processName: "python", serverType: "Django",
            group: nil,
            icon: nil,
            command: "python manage.py runserver",
            workingDirectory: "/Users/tyler/Developer/backend",
            displayDirectory: "~/Developer/backend",
            url: "http://localhost:8000",
            pinned: false, lastSeenAt: nil, startCommand: nil
        ))
        .padding(.horizontal)
    }
    .padding(.vertical, 6)
    .frame(width: 300)
}
