import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: ServerListViewModel
    @State private var groupStore = ServerGroupStore()
    @State private var selectedTab = PorchlightTab.servers
    @State private var selectedServerID: LocalServer.ID?
    @State private var selectedGroupID: ServerGroup.ID?
    @State private var autoRefresh = true
    @State private var refreshInterval = 2.0
    @State private var launchAtLogin = false
    @State private var hideDockIcon = true
    @State private var hideMenuIconWhenEmpty = false

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
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(selectedTab.rawValue)
                    .font(.headline)
            }
        }
        .task {
            groupStore.load()
            await viewModel.refresh()
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

            NavigationSplitView {
                List(selection: $selectedServerID) {
                    Section {
                        if viewModel.servers.isEmpty {
                            CompactEmptyState(
                                title: "No Servers",
                                systemImage: "lightbulb",
                                description: "Start a local development server and it will appear here."
                            )
                        } else {
                            ForEach(viewModel.servers) { server in
                                ServerRowView(server: server)
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
                                            .disabled(server.startCommand == nil)
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
                .navigationSplitViewColumnWidth(min: 180, ideal: 230, max: 280)
            } detail: {
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
            .toolbar(removing: .sidebarToggle)
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

            NavigationSplitView {
                List(selection: $selectedGroupID) {
                    Section {
                        if groupStore.groups.isEmpty {
                            CompactEmptyState(
                                title: "No Groups",
                                systemImage: "folder.badge.plus",
                                description: "Create a group to tag matching servers."
                            )
                        } else {
                            ForEach(groupStore.groups) { group in
                                Label {
                                    Text(group.name)
                                } icon: {
                                    Circle()
                                        .fill(Color(hex: group.color))
                                        .frame(width: 10, height: 10)
                                }
                                .tag(group.id)
                            }
                            .onDelete { offsets in
                                let ids = offsets.map { groupStore.groups[$0].id }
                                ids.forEach(groupStore.deleteGroup)
                                selectFallbackGroup()
                            }
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
                .navigationSplitViewColumnWidth(min: 180, ideal: 230, max: 280)
            } detail: {
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
            .toolbar(removing: .sidebarToggle)
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
                    Toggle("Refresh server list", isOn: $autoRefresh)
                    HStack(spacing: 12) {
                        Toggle("", isOn: $autoRefresh)
                            .labelsHidden()
                            .opacity(0)
                            .disabled(true)
                        Text("Every")
                            .foregroundStyle(autoRefresh ? .primary : .secondary)
                        Stepper("\(Int(refreshInterval)) seconds", value: $refreshInterval, in: 1...30, step: 1)
                            .disabled(!autoRefresh)
                    }
                    Toggle("Launch Porchlight at login", isOn: $launchAtLogin)
                }
            }

            PreferenceRow(label: "Window:") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Hide Dock icon", isOn: $hideDockIcon)
                    Text("Hide the Dock icon when all windows are closed.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            PreferenceRow(label: "Menu Bar:") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Hide icon when no servers are active", isOn: $hideMenuIconWhenEmpty)
                    Text("Keep Porchlight quiet until there is something useful to show.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            PreferenceRow(label: "CLI:") {
                HStack {
                    Text("Manage Porchlight from the Terminal.")
                    Spacer()
                    Button("Show me how") {}
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

                    Button("Report an Issue...") {}
                        .padding(.top, 10)
                }
                .frame(width: 210, alignment: .leading)
            }

            VStack(spacing: 8) {
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
                Image(systemName: tab.icon)
                    .font(.caption)
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

private struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
    }
}

private struct ServerDetailView: View {
    let server: LocalServer
    let viewModel: ServerListViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    StatusDot(color: server.isActive ? .green : .gray)
                    Text(verbatim: "localhost:\(server.port)")
                        .font(.title2.weight(.semibold))
                    Text(server.serverType)
                        .foregroundStyle(.secondary)
                    if server.pinned {
                        Image(systemName: "pin.fill")
                            .foregroundStyle(.secondary)
                    }
                    if let group = server.group {
                        Label(group.name, systemImage: "folder.fill")
                            .foregroundStyle(Color(hex: group.color))
                    }
                }

                HStack(spacing: 8) {
                    Button("Open") { viewModel.open(server) }
                        .disabled(!server.isActive)

                    if server.workingDirectory != nil {
                        Button("Open in Finder") { viewModel.openInFinder(server) }

                        Menu("Open in App") {
                            Button("Visual Studio Code") { viewModel.openInVSCode(server) }
                            Button("Xcode") { viewModel.openInXcode(server) }
                                .disabled(!server.canOpenInXcode)
                        }
                    }

                    if server.isActive {
                        Button("Turn Off", role: .destructive) {
                            Task { await viewModel.kill(server) }
                        }
                    } else {
                        Button("Turn On") {
                            Task { await viewModel.start(server) }
                        }
                        .disabled(server.startCommand == nil)
                    }

                    Button(server.pinned ? "Unpin" : "Pin") {
                        Task { await viewModel.togglePin(server) }
                    }

                    Button("Remove", role: .destructive) {
                        Task { await viewModel.remove(server) }
                    }
                }

                Divider()

                DetailRow(label: "Status", value: server.status.rawValue.capitalized)
                if let group = server.group {
                    DetailRow(label: "Group", value: group.name)
                }
                DetailRow(label: "URL", value: server.url)
                DetailRow(label: "Process", value: "pid \(server.pid) • \(server.processName)")
                DetailRow(label: "Path", value: server.locationText)
                DetailRow(label: "Command", value: server.command)

                if let lastSeenText = server.lastSeenText {
                    DetailRow(label: "Last Seen", value: lastSeenText)
                }

                if let startCommand = server.startCommand {
                    DetailRow(label: "Start Command", value: startCommand)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct GroupDetailView: View {
    let groupID: ServerGroup.ID
    @Bindable var store: ServerGroupStore
    @State private var commandText = ""
    @State private var directoryText = ""

    var body: some View {
        if
            let name = store.binding(for: groupID, keyPath: \.name),
            let color = store.binding(for: groupID, keyPath: \.color),
            let priority = store.binding(for: groupID, keyPath: \.priority),
            let group = store.groups.first(where: { $0.id == groupID })
        {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center, spacing: 10) {
                        Circle()
                            .fill(Color(hex: color.wrappedValue))
                            .frame(width: 12, height: 12)
                        Text(name.wrappedValue)
                            .font(.title2.weight(.semibold))
                    }

                    Divider()

                    DetailEditorRow(label: "Name") {
                        TextField("Group name", text: name)
                            .textFieldStyle(.roundedBorder)
                    }

                    DetailEditorRow(label: "Colour") {
                        HStack {
                            ColorPicker("", selection: colorBinding(color))
                                .labelsHidden()
                            TextField("#34C759", text: color)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }
                    }

                    DetailEditorRow(label: "Command Contains") {
                        ChipEditor(
                            placeholder: "manage.py runserver",
                            text: $commandText,
                            values: group.commandContains,
                            add: { store.addCommand(commandText, to: groupID); commandText = "" },
                            remove: { store.removeCommand($0, from: groupID) }
                        )
                    }

                    DetailEditorRow(label: "Working Directory") {
                        ChipEditor(
                            placeholder: "/Users/tyler/Developer/ausmusicfinder",
                            text: $directoryText,
                            values: group.workingDirectories,
                            add: { store.addWorkingDirectory(directoryText, to: groupID); directoryText = "" },
                            remove: { store.removeWorkingDirectory($0, from: groupID) }
                        )
                    }

                    DetailEditorRow(label: "Priority") {
                        Stepper(value: priority, in: 0...1000, step: 10) {
                            Text(priority.wrappedValue.formatted())
                        }
                    }

                    Divider()

                    Button("Delete Group", role: .destructive) {
                        store.deleteGroup(id: groupID)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            CompactEmptyState(title: "Group Not Found", systemImage: "folder.badge.questionmark")
        }
    }

    private func colorBinding(_ hex: Binding<String>) -> Binding<Color> {
        Binding(
            get: { Color(hex: hex.wrappedValue) },
            set: { hex.wrappedValue = $0.hexString }
        )
    }
}

private struct ChipEditor: View {
    let placeholder: String
    @Binding var text: String
    let values: [String]
    let add: () -> Void
    let remove: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addIfNeeded)
                Button("Add", action: addIfNeeded)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if values.isEmpty {
                Text("No values yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(values, id: \.self) { value in
                        HStack(spacing: 6) {
                            Text(value)
                                .textSelection(.enabled)
                                .lineLimit(1)
                            Button {
                                remove(value)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
                    }
                }
            }
        }
    }

    private func addIfNeeded() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        add()
    }
}

private struct DetailEditorRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .trailing)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CompactEmptyState: View {
    let title: String
    let systemImage: String
    var description: String?

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.callout.weight(.semibold))
            if let description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 8) {
            GridRow {
                Text(label)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 110, alignment: .trailing)
                Text(value)
                    .textSelection(.enabled)
                    .lineLimit(nil)
            }
        }
    }
}
