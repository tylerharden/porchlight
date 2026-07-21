import SwiftUI

struct ServerRowView: View {
    let server: LocalServer
    var isStarting = false
    var showsGroup = true
    var showGroupIcons = true

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
                    if showsGroup, let group = server.group, showGroupIcons {
                        Text(group.name)
                    } else if server.group == nil, server.icon != nil, showGroupIcons {
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

#if DEBUG
#Preview {
    VStack(spacing: 0) {
        ServerRowView(server: PorchlightPreviewData.activeServer)
        .padding(.horizontal)

        Divider()

        ServerRowView(server: PorchlightPreviewData.recentServer)
        .padding(.horizontal)

        Divider()

        ServerRowView(server: PorchlightPreviewData.hiddenServer, isStarting: true)
        .padding(.horizontal)
    }
    .padding(.vertical, 6)
    .frame(width: 300)
}
#endif
