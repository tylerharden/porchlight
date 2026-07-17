import AppKit
import SwiftUI

struct NativeMenuBarView: View {
    @Bindable var viewModel: ServerListViewModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if let errorMessage = viewModel.errorMessage {
            Text("Porchlight CLI failed")
            Text(errorMessage)
        } else if viewModel.servers.isEmpty {
            Text("No local servers running")
            Text("Pinned and recent servers will appear here")
        } else {
            ForEach(viewModel.servers) { server in
                serverMenu(server)
            }
        }

        Divider()

        Button("Refresh") {
            Task { await viewModel.refresh() }
        }
        .disabled(viewModel.isRefreshing)

        Divider()

        Button("Settings...") {
            openSettings()
        }

        Button("Quit Porchlight") {
            NSApplication.shared.terminate(nil)
        }
    }

    private func serverMenu(_ server: LocalServer) -> some View {
        Menu {
            Text(server.locationText)

            Button("Open \(server.url)") {
                open(server.url)
            }

            if server.isActive {
                Button("Kill") {
                    Task { await viewModel.kill(server) }
                }

                Button("Kill and Remove") {
                    Task { await viewModel.killAndRemove(server) }
                }
            } else {
                Button("Start") {}
                    .disabled(true)

                Button("Remove") {
                    Task { await viewModel.remove(server) }
                }
            }
        } label: {
            NativeServerMenuLabel(server: server)
        }
    }

    private func open(_ url: String) {
        guard let url = URL(string: url) else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct NativeServerMenuLabel: View {
    let server: LocalServer

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(server.isActive ? Color.green : Color.gray.opacity(0.55))
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(verbatim: String(server.port))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text(server.serverType)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Text(server.locationText)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}
