import AppKit
import SwiftUI

struct MenuBarView: View {
    @Bindable var viewModel: ServerListViewModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            serverList

            Divider()

            footer
        }
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

            if viewModel.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var serverList: some View {
        Group {
            if let errorMessage = viewModel.errorMessage {
                ErrorStateView(message: errorMessage)
                    .frame(maxWidth: .infinity)
                    .padding(18)
            } else if viewModel.servers.isEmpty {
                EmptyStateView()
                    .frame(maxWidth: .infinity)
                    .padding(24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.servers) { server in
                            ServerRowView(
                                server: server,
                                compact: true,
                                isKilling: viewModel.killingServerIDs.contains(server.id)
                            ) {
                                Task { await viewModel.kill(server) }
                            }
                            .padding(.horizontal, 2)

                            if server.id != viewModel.servers.last?.id {
                                Divider()
                                    .padding(.leading, 42)
                            }
                        }
                    }
                }
                .frame(maxHeight: 360)
            }
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
}

private struct FooterButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "lightbulb")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No local servers running")
                .font(.body)
            Text("Pinned and recent servers will appear here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ErrorStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)
            Text("Porchlight CLI failed")
                .font(.body)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
