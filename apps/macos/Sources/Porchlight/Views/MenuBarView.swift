import AppKit
import SwiftUI

struct MenuBarView: View {
    @Bindable var viewModel: ServerListViewModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 390, height: menuHeight, alignment: .top)
        .padding(.vertical, 6)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Porchlight")
                    .font(.system(size: 13, weight: .semibold))
                Text(summaryText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await viewModel.refresh() }
            } label: {
                ZStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .opacity(viewModel.isRefreshing ? 0 : 1)

                    ProgressView()
                        .controlSize(.small)
                        .opacity(viewModel.isRefreshing ? 1 : 0)
                }
                .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isRefreshing)
            .focusable(false)
            .help("Refresh")
        }
        .frame(height: 40)
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage = viewModel.errorMessage {
            ErrorStateView(message: errorMessage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.servers.isEmpty {
            EmptyStateView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.servers.enumerated()), id: \.element.id) { index, server in
                        ServerRowView(
                            server: server,
                            compact: true,
                            isKilling: viewModel.killingServerIDs.contains(server.id)
                        ) {
                            Task { await viewModel.kill(server) }
                        }

                        if index < viewModel.servers.count - 1 {
                            Divider()
                                .padding(.leading, 38)
                        }
                    }
                }
            }
            .scrollIndicators(viewModel.servers.count > maxVisibleServers ? .visible : .hidden)
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            FooterButton(title: "Settings...") {
                openSettings()
            }

            Divider()

            FooterButton(title: "Quit Porchlight") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private var summaryText: String {
        switch viewModel.activeServerCount {
        case 0:
            return "No servers active"
        case 1:
            return "1 server active"
        default:
            return "\(viewModel.activeServerCount) servers active"
        }
    }

    private var menuHeight: CGFloat {
        let contentHeight: CGFloat

        if viewModel.servers.isEmpty || viewModel.errorMessage != nil {
            contentHeight = 112
        } else {
            contentHeight = min(CGFloat(viewModel.servers.count) * 39, CGFloat(maxVisibleServers) * 39)
        }

        return 40 + contentHeight + 63 + 14
    }

    private var maxVisibleServers: Int { 8 }
}

private struct FooterButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 31)
            .background(selectionBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { isHovered = $0 }
    }

    private var selectionBackground: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(isHovered ? Color(nsColor: .selectedContentBackgroundColor) : Color.clear)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 7) {
            Text("No local servers running")
                .font(.system(size: 13))
            Text("Pinned and recent servers will appear here.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

private struct ErrorStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 7) {
            Text("Porchlight CLI failed")
                .font(.system(size: 13))
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
    }
}
