import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: ServerListViewModel
    @Bindable var settings: AppSettings
    var onTabChange: (String) -> Void = { _ in }
    @State private var groupStore = ServerGroupStore()
    @State private var selectedTab = PorchlightTab.servers
    @State private var selectedServerID: LocalServer.ID?
    @State private var selectedGroupID: ServerGroup.ID?
    private let repositoryURL = URL(string: "https://github.com/tylerharden/porchlight")!
    private let readmeURL = URL(string: "https://github.com/tylerharden/porchlight#readme")!
    private let issuesURL = URL(string: "https://github.com/tylerharden/porchlight/issues/new")!
    private let termsURL = URL(string: "https://github.com/tylerharden/porchlight/blob/main/TERMS_OF_USE.md")!
    private let privacyURL = URL(string: "https://github.com/tylerharden/porchlight/blob/main/PRIVACY_POLICY.md")!

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            switch selectedTab {
            case .servers:
                serversPane
            case .groups:
                groupsPane
            case .settings:
                scrollingPane { settingsPane }
            case .about:
                scrollingPane { aboutPane }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            groupStore.load()
            await viewModel.refresh()
        }
        .onAppear {
            onTabChange(selectedTab.rawValue)
        }
        .onChange(of: selectedTab) { _, tab in
            onTabChange(tab.rawValue)
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                TabButton(tab: .servers, selectedTab: $selectedTab)
                TabButton(tab: .groups, selectedTab: $selectedTab)
                TabButton(tab: .settings, selectedTab: $selectedTab)
                TabButton(tab: .about, selectedTab: $selectedTab)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var serversPane: some View {
        VStack(spacing: 0) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .padding(.top)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HSplitView {
                List(selection: $selectedServerID) {
                    Section {
                        ForEach(viewModel.servers) { server in
                            ServerRowView(
                                server: server,
                                isStarting: viewModel.startingServerIDs.contains(server.id)
                            )
                                .tag(server.id)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    if server.isActive {
                                        Button("Turn Off", role: .destructive) {
                                            Task { await viewModel.kill(server) }
                                        }
                                    } else {
                                        Button("Turn On") {
                                            Task { await viewModel.start(server) }
                                        }
                                        .disabled(server.resolvedStartCommand == nil)
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if server.pinned {
                                        Button("Unpin") {
                                            Task { await viewModel.togglePin(server) }
                                        }
                                    } else {
                                        Button("Remove", role: .destructive) {
                                            Task { await viewModel.remove(server) }
                                        }
                                    }
                                }
                        }
                    } header: {
                        HStack {
                            Text(viewModel.hasActiveServers ? "\(viewModel.activeServerCount) Active" : "Servers")
                            Spacer()
                            Button {
                                Task { await viewModel.refresh() }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isRefreshing)
                        }
                    }
                }
                .listStyle(.sidebar)
                .frame(minWidth: 180, idealWidth: 230, maxWidth: 280)
                .overlay {
                    if viewModel.servers.isEmpty {
                        CompactEmptyState(
                            title: "No Servers",
                            systemImage: "lightbulb",
                            description: "Start a local development server and it will appear here."
                        )
                        .background(Color(nsColor: .windowBackgroundColor))
                    }
                }

                Group {
                    if let selectedServer {
                        ServerDetailView(server: selectedServer, viewModel: viewModel)
                    } else {
                        CompactEmptyState(
                            title: "Select a Server",
                            systemImage: "lightbulb",
                            description: "Choose a port to see details."
                        )
                    }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: selectFallbackServer)
        .onChange(of: viewModel.servers) { _, _ in
            selectFallbackServer()
        }
    }

    private func scrollingPane<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .padding(.horizontal, 46)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var selectedServer: LocalServer? {
        guard let selectedServerID else { return nil }
        return viewModel.servers.first { $0.id == selectedServerID }
    }

    private func selectFallbackServer() {
        guard !viewModel.servers.isEmpty else {
            selectedServerID = nil
            return
        }

        if selectedServer == nil {
            selectedServerID = viewModel.servers.first?.id
        }
    }

    private var groupsPane: some View {
        VStack(spacing: 0) {
            if let errorMessage = groupStore.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .padding(.top)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HSplitView {
                List(selection: $selectedGroupID) {
                    Section {
                        ForEach(groupStore.groups) { group in
                            Label {
                                Text(group.name)
                            } icon: {
                                GroupIconView(icon: group.icon, color: group.color, size: 10)
                            }
                            .tag(group.id)
                        }
                        .onDelete { offsets in
                            let ids = offsets.map { groupStore.groups[$0].id }
                            ids.forEach(groupStore.deleteGroup)
                            selectFallbackGroup()
                        }
                    } header: {
                        HStack {
                            Text("Groups")
                            Spacer()
                            Button {
                                selectedGroupID = groupStore.addGroup()
                            } label: {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.sidebar)
                .frame(minWidth: 180, idealWidth: 230, maxWidth: 280)
                .overlay {
                    if groupStore.groups.isEmpty {
                        CompactEmptyState(
                            title: "No Groups",
                            systemImage: "folder.badge.plus",
                            description: "Create a group to tag matching servers."
                        )
                        .background(Color(nsColor: .windowBackgroundColor))
                    }
                }

                Group {
                    if let selectedGroupID {
                        GroupDetailView(groupID: selectedGroupID, store: groupStore)
                    } else {
                        CompactEmptyState(
                            title: "Select a Group",
                            systemImage: "folder",
                            description: "Groups match servers without changing their type."
                        )
                    }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: selectFallbackGroup)
        .onChange(of: groupStore.groups) { _, _ in
            selectFallbackGroup()
        }
    }

    private func selectFallbackGroup() {
        guard !groupStore.groups.isEmpty else {
            selectedGroupID = nil
            return
        }

        if selectedGroupID == nil || !groupStore.groups.contains(where: { $0.id == selectedGroupID }) {
            selectedGroupID = groupStore.groups.first?.id
        }
    }

    private var settingsPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            PreferenceRow(label: "General:") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Refresh server list", isOn: $settings.autoRefresh)
                    HStack(spacing: 12) {
                        Toggle("", isOn: $settings.autoRefresh)
                            .labelsHidden()
                            .opacity(0)
                            .disabled(true)
                        Text("Every")
                            .foregroundStyle(settings.autoRefresh ? .primary : .secondary)
                        Stepper("\(Int(settings.refreshInterval)) seconds", value: $settings.refreshInterval, in: 1...30, step: 1)
                            .disabled(!settings.autoRefresh)
                    }
                    Toggle("Launch Porchlight at login", isOn: $settings.launchAtLogin)
                    if let errorMessage = settings.errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                }
            }

            PreferenceRow(label: "Window:") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Hide Dock icon", isOn: $settings.hideDockIcon)
                    Text("Hide the Dock icon when all windows are closed.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            PreferenceRow(label: "Menu Bar:") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Hide icon when no servers are active", isOn: $settings.hideMenuIconWhenEmpty)
                    Text("Keep Porchlight quiet until there is something useful to show.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            PreferenceRow(label: "CLI:") {
                HStack {
                    Text("Manage Porchlight from the Terminal.")
                    Spacer()
                    Button("Show me how") { open(readmeURL) }
                }
            }
        }
        .toggleStyle(.checkbox)
    }

    private var aboutPane: some View {
        VStack(spacing: 34) {
            HStack(alignment: .top, spacing: 34) {
                Image(nsImage: PorchlightAppIcon.image)
                    .resizable()
                    .frame(width: 128, height: 128)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Porchlight")
                        .font(.title3.weight(.semibold))

                    Text("Version 0.1.0")
                        .foregroundStyle(.secondary)

                    Text("Find the servers you left on.")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        LinkButton("Acknowledgements", url: repositoryURL)
                        LinkButton("Privacy Policy", url: privacyURL)
                        LinkButton("Terms of Use", url: termsURL)
                    }
                    .padding(.top, 10)

                    Button("Report an Issue...") { open(issuesURL) }
                        .padding(.top, 10)
                }
                .frame(width: 210, alignment: .leading)
            }

            VStack(spacing: 12) {
                Text("Porchlight runs locally and uses the bundled Rust CLI to inspect development servers.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Text("© 2026 Porchlight. All rights reserved.")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .frame(maxWidth: 460)
        }
        .frame(maxWidth: .infinity, minHeight: 340, alignment: .center)
    }

    private func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

private enum PorchlightTab: String, CaseIterable, Identifiable {
    case servers = "Servers"
    case groups = "Groups"
    case settings = "Settings"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .servers: "lightbulb"
        case .groups: "folder"
        case .settings: "slider.horizontal.3"
        case .about: "info.circle"
        }
    }
}

private struct TabButton: View {
    let tab: PorchlightTab
    @Binding var selectedTab: PorchlightTab

    var body: some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                if tab == .servers {
                    Image(nsImage: PorchlightStatusIcon.image(isActive: selectedTab == tab))
                        .resizable()
                        .frame(width: 13, height: 13)
                } else {
                    Image(systemName: tab.icon)
                        .font(.caption)
                }
                Text(tab.rawValue)
                    .font(.caption2)
            }
            .frame(minWidth: 58, minHeight: 36)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
            .background {
                if selectedTab == tab {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.quaternary, lineWidth: 1)
                        }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PreferenceRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            Text(label)
                .font(.body.weight(.semibold))
                .frame(width: 124, alignment: .trailing)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct LinkButton: View {
    let title: String
    let url: URL

    init(_ title: String, url: URL) {
        self.title = title
        self.url = url
    }

    var body: some View {
        Button(title) {
            NSWorkspace.shared.open(url)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.blue)
    }
}

#Preview {
    let vm = ServerListViewModel()
    vm.servers = [
        LocalServer(
            id: "1", port: 3000, pid: 1234, status: .active,
            processName: "node", serverType: "Next.js",
            group: ServerGroupMatch(id: "g1", name: "Frontend", color: "#007AFF", icon: nil),
            icon: nil,
            command: "next dev",
            workingDirectory: "/Users/tyler/Developer/myapp",
            displayDirectory: "~/Developer/myapp",
            url: "http://localhost:3000",
            pinned: true, lastSeenAt: nil, startCommand: "npm run dev"
        ),
        LocalServer(
            id: "2", port: 8000, pid: 5678, status: .recent,
            processName: "python", serverType: "Django",
            group: nil,
            icon: nil,
            command: "python manage.py runserver",
            workingDirectory: "/Users/tyler/Developer/backend",
            displayDirectory: "~/Developer/backend",
            url: "http://localhost:8000",
            pinned: false, lastSeenAt: nil, startCommand: nil
        ),
    ]
    return SettingsView(viewModel: vm, settings: AppSettings())
        .frame(width: 680, height: 520)
}
