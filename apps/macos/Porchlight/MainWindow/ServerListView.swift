import AppKit
import SwiftUI

struct ServerListView: View {
    @Bindable var viewModel: ServerListViewModel
    @Binding var selectedServerID: LocalServer.ID?
    @State private var isShowingHiddenServers = false
    let showGroupIcons: Bool

    var body: some View {
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
                        EmptyView()
                            .frame(height: 0)
                            .listRowSeparator(.hidden)
                    } header: {
                        ServerListSectionHeader(
                            title: viewModel.hasActiveServers ? "\(viewModel.activeServerCount) Active" : "Servers",
                            isRefreshing: viewModel.isRefreshing,
                            refresh: { Task { await viewModel.refresh() } }
                        )
                    }
                    .listSectionSeparator(.hidden)

                    ForEach(visibleServerSections) { section in
                        Section {
                            ForEach(section.servers) { server in
                                serverRow(server, showsGroup: section.group == nil)
                            }
                        } header: {
                            if let group = section.group {
                                ServerGroupHeaderView(group: group, showIcon: showGroupIcons)
                            }
                        }
                    }

                    if !hiddenServers.isEmpty {
                        Section {
                            if isShowingHiddenServers {
                                ForEach(hiddenServers) { server in
                                    serverRow(server, showsGroup: true)
                                }
                            }
                        } header: {
                            ServerListSectionHeader(
                                title: "Show Hidden",
                                isRefreshing: viewModel.isRefreshing,
                                isExpanded: $isShowingHiddenServers,
                                refresh: nil
                            )
                        }
                    }
                }
                .listStyle(.sidebar)
                .frame(minWidth: 180, idealWidth: 230, maxWidth: 280)
                .overlay {
                    if viewModel.isLoadingInitialServers {
                        CompactLoadingState(title: "Loading Servers")
                            .background(Color(nsColor: .windowBackgroundColor))
                    } else if viewModel.servers.isEmpty {
                        CompactEmptyState(
                            title: "No Servers",
                            systemImage: "lightbulb",
                            description: "Start a local development server and it will appear here."
                        )
                        .background(Color(nsColor: .windowBackgroundColor))
                    }
                }

                Group {
                    if viewModel.isLoadingInitialServers {
                        CompactLoadingState(title: "Loading Details")
                    } else if let selectedServer {
                        ServerDetailView(server: selectedServer, viewModel: viewModel, showGroupIcons: showGroupIcons)
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

    private var selectedServer: LocalServer? {
        guard let selectedServerID else { return nil }
        return viewModel.servers.first { $0.id == selectedServerID }
    }

    private var visibleServerSections: [ServerSection] {
        viewModel.servers.filter { !$0.hidden }.groupedSections()
    }

    private var hiddenServers: [LocalServer] {
        viewModel.servers.filter(\.hidden)
    }

    private func serverRow(_ server: LocalServer, showsGroup: Bool) -> some View {
        ServerRowView(
            server: server,
            isStarting: viewModel.startingServerIDs.contains(server.id),
            showsGroup: showsGroup,
            showGroupIcons: showGroupIcons
        )
            .tag(server.id)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if server.hidden {
                    Button("Unhide") {
                        Task { await viewModel.unhide(server) }
                    }
                } else if server.isActive {
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
                if server.hidden {
                    Button("Remove", role: .destructive) {
                        Task { await viewModel.remove(server) }
                    }
                } else if server.pinned {
                    Button("Unpin") {
                        Task { await viewModel.togglePin(server) }
                    }
                } else {
                    Button("Hide") {
                        Task { await viewModel.hide(server) }
                    }
                    Button("Remove", role: .destructive) {
                        Task { await viewModel.remove(server) }
                    }
                }
            }
    }

    private func selectFallbackServer() {
        let visibleServers = viewModel.servers.filter { !$0.hidden }
        guard !visibleServers.isEmpty else {
            selectedServerID = nil
            return
        }

        if selectedServer == nil || selectedServer?.hidden == true {
            selectedServerID = visibleServers.first?.id
        }
    }
}

#Preview {
    ServerListView(
        viewModel: ServerListViewModel(),
        selectedServerID: .constant(nil),
        showGroupIcons: true
    )
}
