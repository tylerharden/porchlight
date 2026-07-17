import SwiftUI

struct ServerRowView: View {
    let server: LocalServer
    var compact = false
    var isKilling = false
    var onKill: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            statusIcon

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(verbatim: String(server.port))
                        .font(.system(size: compact ? 13 : 14, weight: .semibold, design: .rounded))

                    Text(server.serverType)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)

                    if server.pinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(server.locationText)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 10)

            actions
        }
        .frame(height: compact ? 38 : 44)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .opacity(server.isActive ? 1 : 0.68)
    }

    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(server.isActive ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 7, height: 7)
        }
        .frame(width: 18, height: 18)
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
            ZStack {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }

                Label(title, systemImage: systemImage)
                    .labelStyle(.iconOnly)
                    .opacity(isLoading ? 0 : 1)
            }
            .font(.system(size: 10, weight: .semibold))
            .frame(width: 22, height: 20)
        }
        .buttonStyle(.plain)
        .disabled(action == nil || isLoading)
        .focusable(false)
        .help(title)
    }
}
