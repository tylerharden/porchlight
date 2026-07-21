import AppKit
import SwiftUI

struct GroupsListView: View {
    @Bindable var groupStore: ServerGroupStore
    @Binding var selectedGroupID: ServerGroup.ID?
    let showGroupIcons: Bool

    var body: some View {
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
                        ForEach(visibleGroupSummaries) { group in
                            GroupRowView(group: group, showIcon: showGroupIcons)
                        }
                        .onDelete { offsets in
                            let groups = visibleGroupSummaries
                            let ids = offsets
                                .compactMap { groups.indices.contains($0) ? groups[$0] : nil }
                                .filter(\.manual)
                                .map(\.id)
                            ids.forEach(groupStore.deleteGroup)
                            selectFallbackGroup()
                        }
                    } header: {
                        ServerListSectionHeader(
                            title: Strings.GroupsList.groupsHeader,
                            isRefreshing: false,
                            refresh: nil,
                            trailingAction: { selectedGroupID = groupStore.addGroup() },
                            trailingActionIcon: "plus"
                        )
                    }

                    if !hiddenGroupSummaries.isEmpty {
                        Section(Strings.GroupsList.hidden) {
                            ForEach(hiddenGroupSummaries) { group in
                                GroupRowView(group: group, showIcon: showGroupIcons)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .frame(minWidth: 180, idealWidth: 230, maxWidth: 280)
                .overlay {
                    if groupStore.isLoadingInitialGroups {
                        CompactLoadingState(title: Strings.GroupsList.loadingGroups)
                            .background(Color(nsColor: .windowBackgroundColor))
                    } else if groupStore.summaries.isEmpty {
                        CompactEmptyState(
                            title: Strings.GroupsList.noGroups,
                            systemImage: "folder.badge.plus",
                            description: Strings.GroupsList.noGroupsDescription
                        )
                        .background(Color(nsColor: .windowBackgroundColor))
                    }
                }

                Group {
                    if groupStore.isLoadingInitialGroups {
                        CompactLoadingState(title: Strings.ServerList.loadingDetails)
                    } else if let selectedGroupID {
                        GroupDetailView(groupID: selectedGroupID, store: groupStore)
                    } else {
                        CompactEmptyState(
                            title: Strings.GroupsList.selectGroup,
                            systemImage: "folder",
                            description: Strings.GroupsList.selectGroupDescription
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

    private var visibleGroupSummaries: [GroupSummary] {
        groupStore.summaries.filter { !$0.hidden }
    }

    private var hiddenGroupSummaries: [GroupSummary] {
        groupStore.summaries.filter(\.hidden)
    }

    private func selectFallbackGroup() {
        let visibleGroups = visibleGroupSummaries
        guard !visibleGroups.isEmpty else {
            selectedGroupID = nil
            return
        }

        if selectedGroupID == nil || hiddenGroupSummaries.contains(where: { $0.id == selectedGroupID }) {
            selectedGroupID = visibleGroups.first?.id
        }
    }
}

#if DEBUG
#Preview {
    GroupsListView(
        groupStore: ServerGroupStore(),
        selectedGroupID: .constant(nil),
        showGroupIcons: true
    )
}
#endif
