import SwiftUI

struct ServerDetailView: View {
    let server: LocalServer
    let viewModel: ServerListViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            StatusDot(color: server.isActive ? .green : .gray)
                            Text(verbatim: "localhost:\(server.port)")
                                .font(.title2.weight(.semibold))
                        }

                        Spacer()

                        Button {
                            Task { await viewModel.togglePin(server) }
                        } label: {
                            Label(server.pinned ? "Unpin" : "Pin", systemImage: server.pinned ? "pin.fill" : "pin")
                        }
                        .labelStyle(.iconOnly)
                        .help(server.pinned ? "Unpin" : "Pin")
                    }

                    HStack(spacing: 6) {
                        Text(server.serverType)
                            .foregroundStyle(.secondary)
                        if let group = server.group {
                            Text("•")
                                .foregroundStyle(.tertiary)
                            HStack(spacing: 4) {
                                GroupIconView(icon: server.icon ?? group.icon, color: group.color ?? "#8E8E93", size: 12)
                                Text(group.name)
                            }
                            .foregroundStyle(Color(hex: group.color ?? "#8E8E93"))
                        } else if server.icon != nil {
                            GroupIconView(icon: server.icon, color: "#8E8E93", size: 12)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        if server.isActive {
                            Button("Kill", role: .destructive) {
                                Task { await viewModel.kill(server) }
                            }
                        } else {
                            Button("Start") {
                                Task { await viewModel.start(server) }
                            }
                            .disabled(server.resolvedStartCommand == nil)
                        }

                        Button("Remove", role: .destructive) {
                            Task { await viewModel.remove(server) }
                        }

                        Button("Hide") {
                            Task { await viewModel.hide(server) }
                        }
                    }

                    Divider()

                    HStack(spacing: 8) {
                        Button("Open") { viewModel.open(server) }
                            .disabled(!server.isActive)

                        if server.workingDirectory != nil {
                            Button("Open in Finder") { viewModel.openInFinder(server) }

                            Menu("Open in App") {
                                Button("Visual Studio Code") { viewModel.openInVSCode(server) }
                                Button("Xcode") { viewModel.openInXcode(server) }
                                    .disabled(!server.canOpenInXcode)
                            }
                        }
                    }
                }

                Divider()

                DetailRow(label: "Status", value: server.status.rawValue.capitalized)
                if let group = server.group {
                    DetailRow(label: "Group", value: group.name)
                    DetailRow(label: "Group Kind", value: "\(group.kind) • \(group.role)")
                }
                DetailRow(label: "URL", value: server.url)
                DetailRow(label: "Process", value: "pid \(server.pid) • \(server.processName)")
                DetailRow(label: "Path", value: server.locationText)
                DetailRow(label: "Command", value: server.command)

                if let lastSeenText = server.lastSeenText {
                    DetailRow(label: "Last Seen", value: lastSeenText)
                }

                if let startCommand = server.startCommand {
                    DetailRow(label: "Start Command", value: startCommand)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 8) {
            GridRow {
                Text(label)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 110, alignment: .trailing)
                Text(value)
                    .textSelection(.enabled)
                    .lineLimit(nil)
            }
        }
    }
}

#Preview("Active server") {
    ServerDetailView(
        server: LocalServer(
            id: "1", port: 3000, pid: 1234, status: .active,
            processName: "node", serverType: "Next.js",
            icon: nil,
            group: ServerGroupMatch(id: "myapp", name: "Myapp", kind: "Next.js", role: "Frontend", color: "#007AFF", icon: nil, confidence: 1, source: "manual group"),
            command: "next dev",
            workingDirectory: "/Users/tyler/Developer/myapp",
            displayDirectory: "~/Developer/myapp",
            url: "http://localhost:3000",
            pinned: true, lastSeenAt: nil, startCommand: "npm run dev"
        ),
        viewModel: ServerListViewModel()
    )
    .frame(width: 460, height: 380)
}

#Preview("Inactive server") {
    ServerDetailView(
        server: LocalServer(
            id: "2", port: 8000, pid: 5678, status: .recent,
            processName: "python", serverType: "Django",
            icon: nil,
            group: nil,
            command: "python manage.py runserver",
            workingDirectory: nil,
            displayDirectory: nil,
            url: "http://localhost:8000",
            pinned: false, lastSeenAt: "2026-07-16T10:00:00Z", startCommand: nil
        ),
        viewModel: ServerListViewModel()
    )
    .frame(width: 460, height: 380)
}
