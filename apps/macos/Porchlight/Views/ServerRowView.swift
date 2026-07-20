import SwiftUI

struct ServerRowView: View {
    let server: LocalServer
    var isStarting = false
    var showsGroup = true

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            statusIndicator
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(verbatim: String(server.port))
                        .font(.body.weight(.medium))

                    Text(server.serverType)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if server.pinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 5) {
                    if showsGroup, let group = server.group {
                        GroupIconView(icon: server.icon ?? group.icon, color: group.color ?? "#8E8E93", size: 8)

                        Text(group.name)
                    } else if server.icon != nil {
                        GroupIconView(icon: server.icon, color: "#8E8E93", size: 8)
                    }

                    Text(server.locationText)
                        .truncationMode(.middle)

                    if let lastSeenText = server.lastSeenText, !server.isActive {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(lastSeenText)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
        .opacity(server.isActive || isStarting ? 1 : 0.62)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if isStarting {
            ProgressView()
                .controlSize(.small)
                .frame(width: 12, height: 12)
        } else {
            Circle()
                .fill(server.isActive ? Color.green : Color.gray.opacity(0.45))
                .frame(width: 12, height: 12)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        ServerRowView(server: LocalServer(
            id: "1", port: 3000, pid: 1234, status: .active,
            processName: "node", serverType: "Next.js",
            icon: nil,
            group: ServerGroupMatch(id: "myapp", name: "Myapp", kind: "Next.js", role: "Frontend", color: "#007AFF", icon: nil, confidence: 1, source: "manual group"),
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
            icon: nil,
            group: nil,
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
