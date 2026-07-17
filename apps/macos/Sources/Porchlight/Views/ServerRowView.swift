import SwiftUI

struct ServerRowView: View {
    let server: LocalServer
    var compact = false
    var isKilling = false
    var onKill: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            statusIcon

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(verbatim: String(server.port))
                        .font(.system(size: compact ? 14 : 15, weight: .semibold, design: .rounded))

                    Text(server.serverType)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary.opacity(0.7), in: Capsule())

                    if server.pinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(server.locationText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 10)

            actions
        }
        .padding(.horizontal, 11)
        .padding(.vertical, compact ? 10 : 12)
        .porchlightGlass(cornerRadius: 14)
        .opacity(server.isActive ? 1 : 0.68)
    }

    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(server.isActive ? Color.green.opacity(0.16) : Color.gray.opacity(0.12))
            Circle()
                .fill(server.isActive ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 8, height: 8)
        }
        .frame(width: 24, height: 24)
    }

    private var actions: some View {
        HStack(spacing: 5) {
            if server.isActive {
                ActionChip(title: "Kill", systemImage: "xmark", isLoading: isKilling, action: onKill)
            } else {
                ActionChip(title: "Start", systemImage: "play.fill")
                ActionChip(title: "Remove", systemImage: "minus")
            }
        }
    }
}

private struct ActionChip: View {
    let title: String
    let systemImage: String
    var isLoading = false
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Label(title, systemImage: systemImage)
                        .labelStyle(.iconOnly)
                }
            }
            .font(.system(size: 10, weight: .semibold))
            .frame(width: 24, height: 22)
            .background(.quaternary.opacity(0.75), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(action == nil || isLoading)
        .help(title)
    }
}
