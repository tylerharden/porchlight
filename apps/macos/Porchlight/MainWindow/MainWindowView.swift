import AppKit
import SwiftUI

struct MainWindowView: View {
    @Bindable var viewModel: ServerListViewModel
    @Bindable var settings: AppSettings
    var onTabChange: (String) -> Void = { _ in }
    @State private var groupStore = ServerGroupStore()
    @State private var selectedTab = PorchlightTab.servers
    @State private var selectedServerID: LocalServer.ID?
    @State private var selectedGroupID: ServerGroup.ID?

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
                scrollingPane { SettingsTabView(settings: settings) }
            case .about:
                scrollingPane { AboutTabView() }
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




}

// MARK: - Helper Views

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

#Preview {
    let vm = ServerListViewModel()
    vm.servers = [
        PorchlightPreviewData.activeServer,
        PorchlightPreviewData.recentServer,
        PorchlightPreviewData.hiddenServer,
    ]
    vm.hasLoadedServers = true
    return MainWindowView(viewModel: vm, settings: AppSettings())
        .frame(width: 680, height: 520)
}
