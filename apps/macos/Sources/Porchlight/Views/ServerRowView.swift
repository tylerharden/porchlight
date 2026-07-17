import SwiftUI

struct ServerRowView: View {
    let server: LocalServer
    var compact = false
    var isKilling = false
    var isExpanded = false
    var onToggleDetails: (() -> Void)?

    var body: some View {
        Button {
            onToggleDetails?()
        } label: {
            HStack(alignment: .center, spacing: 8) {
                statusIcon

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(verbatim: String(server.port))
                            .font(.system(size: compact ? 13 : 14, weight: .semibold, design: .rounded))

                        Text(server.serverType)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary.opacity(0.7), in: Capsule())

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

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 22, height: 20)
            }
            .frame(height: compact ? 38 : 44)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .opacity(server.isActive ? 1 : 0.68)
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(server.isActive ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 7, height: 7)
        }
        .frame(width: 18, height: 18)
    }

}
