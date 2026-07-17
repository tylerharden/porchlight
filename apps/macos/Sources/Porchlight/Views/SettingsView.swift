import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: ServerListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            if viewModel.servers.isEmpty {
                ContentUnavailableView(
                    "No Servers",
                    systemImage: "lightbulb",
                    description: Text("Current, pinned, and recent servers will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.servers) { server in
                    ServerRowView(server: server)
                }
                .listStyle(.plain)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("My Servers")
                    .font(.title2.weight(.semibold))
                Text("Pin servers here to keep them visible in the menu bar.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .padding(20)
    }
}
