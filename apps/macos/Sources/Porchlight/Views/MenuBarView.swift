import AppKit
import SwiftUI

struct MenuBarView: View {
    @Bindable var viewModel: ServerListViewModel
    @Environment(\.openSettings) private var openSettings
    @State private var expandedServerID: String?

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
                            isKilling: viewModel.killingServerIDs.contains(server.id),
                            isExpanded: expandedServerID == server.id
                        ) {
                            expandedServerID = expandedServerID == server.id ? nil : server.id
                        }
                        .onHover { hovering in
                            if hovering {
                                expandedServerID = server.id
                            }
                        }

                        if expandedServerID == server.id {
                            ServerDetailView(server: server, viewModel: viewModel)
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
            let rowHeight = CGFloat(viewModel.servers.count) * 39
            let detailHeight: CGFloat = expandedServerID == nil ? 0 : 216
            contentHeight = min(rowHeight + detailHeight, CGFloat(maxVisibleServers) * 39 + 216)
        }

        return 40 + contentHeight + 63 + 14
    }

    private var maxVisibleServers: Int { 8 }
}

private struct ServerDetailView: View {
    let server: LocalServer
    @Bindable var viewModel: ServerListViewModel

    var body: some View {
        VStack(spacing: 0) {
            DetailButton(title: "Open Address", detail: server.url) {
                open(server.url)
            }

            if let workingDirectory = server.workingDirectory {
                DetailButton(title: "Open in Finder", detail: server.locationText) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: workingDirectory))
                }

                DetailButton(title: "Open in VS Code", detail: "code \(server.locationText)") {
                    openWithCommand("/usr/local/bin/code", argument: workingDirectory)
                }

                if workingDirectory.hasSuffix(".xcodeproj") || workingDirectory.hasSuffix(".xcworkspace") {
                    DetailButton(title: "Open in Xcode", detail: server.locationText) {
                        NSWorkspace.shared.open(URL(fileURLWithPath: workingDirectory))
                    }
                }
            }

            DetailInfo(title: "Process", value: "pid \(server.pid) • \(server.processName)")
            DetailInfo(title: "Command", value: server.command)

            if server.isActive {
                DetailButton(title: "Kill", detail: "Switch this server off") {
                    Task { await viewModel.kill(server) }
                }

                DetailButton(title: "Kill and Remove", detail: "Stop and remove from recents") {
                    Task { await viewModel.killAndRemove(server) }
                }
            } else {
                DetailButton(title: "Remove", detail: "Remove from recents") {
                    Task { await viewModel.remove(server) }
                }
            }
        }
        .padding(.leading, 38)
        .padding(.trailing, 8)
        .padding(.bottom, 6)
    }

    private func open(_ url: String) {
        guard let url = URL(string: url) else { return }
        NSWorkspace.shared.open(url)
    }

    private func openWithCommand(_ executable: String, argument: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = [argument]
        try? process.run()
    }
}

private struct DetailButton: View {
    let title: String
    let detail: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            DetailRow(title: title, detail: detail)
                .background(selectionBackground)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { isHovered = $0 }
    }

    private var selectionBackground: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(isHovered ? Color(nsColor: .selectedContentBackgroundColor) : Color.clear)
            .padding(.horizontal, -4)
    }
}

private struct DetailInfo: View {
    let title: String
    let value: String

    var body: some View {
        DetailRow(title: title, detail: value)
            .opacity(0.72)
    }
}

private struct DetailRow: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 11))
            Spacer(minLength: 10)
            Text(detail)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(height: 24)
        .contentShape(Rectangle())
    }
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
