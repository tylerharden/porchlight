import SwiftUI

struct ServerRowView: View {
    let server: LocalServer
    var compact = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(server.port)")
                        .font(.body.weight(.medium))

                    if server.pinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(server.locationText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 6) {
                    Text(server.serverType)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Circle()
                        .fill(server.isActive ? Color.green : Color.gray.opacity(0.45))
                        .frame(width: 8, height: 8)
                }

                HStack(spacing: 6) {
                    if server.isActive {
                        Button("Kill") {}
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .disabled(true)
                    } else {
                        Button("Start") {}
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .disabled(true)

                        Button("Remove") {}
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .disabled(true)
                    }
                }

                if !server.isActive, let lastSeenAt = server.lastSeenAt {
                    Text("last seen \(lastSeenAt)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, compact ? 10 : 12)
        .opacity(server.isActive ? 1 : 0.68)
    }
}
