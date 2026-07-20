import AppKit
import SwiftUI

struct GroupsListView: View {
    @Bindable var groupStore: ServerGroupStore
    @Binding var selectedGroupID: ServerGroup.ID?

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
                            Label {
                                HStack {
                                    Text(group.name)
                                    Spacer()
                                    Text(group.manual ? "Manual" : "Auto")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                GroupIconView(icon: group.icon, color: group.color ?? "#8E8E93", size: 10)
                            }
                            .tag(group.id)
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
                            title: "Groups",
                            isRefreshing: false,
                            refresh: nil,
                            trailingAction: { selectedGroupID = groupStore.addGroup() },
                            trailingActionIcon: "plus"
                        )
                    }

                    if !hiddenGroupSummaries.isEmpty {
                        Section("Hidden") {
                            ForEach(hiddenGroupSummaries) { group in
                                Label {
                                    HStack {
                                        Text(group.name)
                                        Spacer()
                                        Text(group.manual ? "Manual" : "Auto")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    GroupIconView(icon: group.icon, color: group.color ?? "#8E8E93", size: 10)
                                }
                                .tag(group.id)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .frame(minWidth: 180, idealWidth: 230, maxWidth: 280)
                .overlay {
                    if groupStore.isLoadingInitialGroups {
                        CompactLoadingState(title: "Loading Groups")
                            .background(Color(nsColor: .windowBackgroundColor))
                    } else if groupStore.summaries.isEmpty {
                        CompactEmptyState(
                            title: "No Groups",
                            systemImage: "folder.badge.plus",
                            description: "Create a group or let Porchlight discover active groups automatically."
                        )
                        .background(Color(nsColor: .windowBackgroundColor))
                    }
                }

                Group {
                    if groupStore.isLoadingInitialGroups {
                        CompactLoadingState(title: "Loading Details")
                    } else if let selectedGroupID {
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

#Preview {
    GroupsListView(
        groupStore: ServerGroupStore(),
        selectedGroupID: .constant(nil)
    )
}
