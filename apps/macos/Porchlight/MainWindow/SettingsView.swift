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
    @State private var isConfirmingReset = false
    @State private var isResetting = false
    private let repositoryURL = URL(string: "https://github.com/tylerharden/porchlight")!
    private let readmeURL = URL(string: "https://github.com/tylerharden/porchlight#readme")!
    private let issuesURL = URL(string: "https://github.com/tylerharden/porchlight/issues/new")!
    private let termsURL = URL(string: "https://github.com/tylerharden/porchlight/blob/main/TERMS_OF_USE.md")!
    private let privacyURL = URL(string: "https://github.com/tylerharden/porchlight/blob/main/PRIVACY_POLICY.md")!

    var body: some View {
        VStack(spacing: 0) {
            SettingsTabHeader(selectedTab: $selectedTab)
            Divider()

            switch selectedTab {
            case .servers:
                ServerListView(
                    viewModel: viewModel,
                    selectedServerID: $selectedServerID
                )
            case .groups:
                GroupsListView(
                    groupStore: groupStore,
                    selectedGroupID: $selectedGroupID
                )
            case .settings:
                scrollingPane { settingsPane }
            case .about:
                scrollingPane { aboutPane }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await groupStore.load()
            await viewModel.refresh()
        }
        .onAppear {
            onTabChange(selectedTab.rawValue)
        }
        .onChange(of: selectedTab) { _, tab in
            onTabChange(tab.rawValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: ServerGroupStore.didChangeNotification)) { _ in
            Task { await viewModel.refresh() }
        }
        .confirmationDialog(
            "Reset Porchlight to defaults?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset Porchlight", role: .destructive) {
                Task { await resetPorchlight() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes saved server history, pins, groups, classification rules, and Porchlight settings.")
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

            PreferenceRow(label: "Groups:") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Show automatic groups", isOn: $settings.showAutomaticGroups)
                    Text("When disabled, only groups you create manually are shown.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Toggle("Show app services", isOn: $settings.showAppServices)
                    Text("When disabled, hides background listeners from apps like Adobe Creative Cloud and Ableton.")
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

            Divider()
                .padding(.vertical, 4)

            PreferenceRow(label: "Reset:") {
                VStack(alignment: .leading, spacing: 8) {
                    Button("Reset Porchlight to Defaults", role: .destructive) {
                        isConfirmingReset = true
                    }
                    .disabled(isResetting)

                    Text("Removes saved server history, pins, groups, classification rules, and settings.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .toggleStyle(.checkbox)
    }

    private func resetPorchlight() async {
        guard !isResetting else { return }
        isResetting = true
        defer { isResetting = false }

        await settings.resetToDefaults()
        await groupStore.load()
        selectedGroupID = nil
        selectedServerID = nil
        await viewModel.refresh()
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

struct ServerGroupHeaderView: View {
    let group: ServerGroupMatch

    var body: some View {
        HStack(spacing: 6) {
            GroupIconView(icon: group.icon, color: group.color ?? "#8E8E93", size: 10)
            Text(group.name)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(hex: group.color ?? "#8E8E93"))
        }
        .textCase(nil)
    }
}

struct ServerListSectionHeader: View {
    let title: String
    let isRefreshing: Bool
    var isExpanded: Binding<Bool>?
    let refresh: (() -> Void)?
    var trailingAction: (() -> Void)?
    var trailingActionIcon: String = "plus"

    var body: some View {
        HStack(spacing: 6) {
            if let isExpanded {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isExpanded.wrappedValue.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Text(title)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Spacer()

            if let trailingAction {
                Button(action: trailingAction) {
                    Image(systemName: trailingActionIcon)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            } else if let refresh {
                Button(action: refresh) {
                    RefreshIcon(isRefreshing: isRefreshing)
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)
                .padding(.trailing, 8)
            }
        }
    }
}

struct RefreshIcon: View {
    let isRefreshing: Bool

    var body: some View {
        if isRefreshing {
            ProgressView()
                .controlSize(.small)
        } else {
            Image(systemName: "arrow.clockwise")
        }
    }
}

struct CompactLoadingState: View {
    let title: String

    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum PorchlightTab: String, CaseIterable, Identifiable {
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

struct TabButton: View {
    let tab: PorchlightTab
    @Binding var selectedTab: PorchlightTab

    var body: some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                if tab == .servers {
                    Image(nsImage: PorchlightStatusIcon.image(isActive: false))
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: tab.icon)
                        .font(.title3)
                }
                Text(tab.rawValue)
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(minWidth: 72, minHeight: 52)
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
        PorchlightPreviewData.activeServer,
        PorchlightPreviewData.recentServer,
        PorchlightPreviewData.hiddenServer,
    ]
    vm.hasLoadedServers = true
    return SettingsView(viewModel: vm, settings: AppSettings())
        .frame(width: 680, height: 520)
}
