import AppKit
import SwiftUI

struct MainWindowView: View {
    @Bindable var viewModel: ServerListViewModel
    @Bindable var settings: AppSettings
    @State private var groupStore = ServerGroupStore()
    @State private var selectedTab = PorchlightTab.servers
    @State private var selectedServerID: LocalServer.ID?
    @State private var selectedGroupID: ServerGroup.ID?

    var body: some View {
        VStack(spacing: 0) {
            MainWindowTabHeader(selectedTab: $selectedTab)
            Divider()

            switch selectedTab {
            case .servers:
                ServerListView(
                    viewModel: viewModel,
                    selectedServerID: $selectedServerID,
                    showGroupIcons: settings.showGroupIcons
                )
            case .groups:
                GroupsListView(
                    groupStore: groupStore,
                    selectedGroupID: $selectedGroupID,
                    showGroupIcons: settings.showGroupIcons
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

struct ServerGroupHeaderView: View {
    let group: ServerGroupMatch
    let showIcon: Bool

    var body: some View {
        HStack(spacing: 6) {
            if showIcon {
                GroupIconView(icon: group.icon, color: group.color ?? "#8E8E93", size: 10)
            }
            Text(group.name)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(hex: group.color ?? "#8E8E93"))
        }
        .textCase(nil)
        .padding(.top, -12)
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
