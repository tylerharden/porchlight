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
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Porchlight")
                    .font(.headline)
                Text(summaryText)
                    .font(.caption)
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
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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
                            ServerRowView(server: server, compact: true)
                            Divider()
                                .padding(.leading, 14)
                        }
                    }
                }
                .frame(maxHeight: 360)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Button {
                openSettings()
            } label: {
                HStack {
                    Label("Settings...", systemImage: "gearshape")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Label("Quit Porchlight", systemImage: "power")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
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
