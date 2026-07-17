import SwiftUI

@main
struct PorchlightApp: App {
    @State private var viewModel = ServerListViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
                .frame(width: 390)
                .task {
                    await viewModel.start()
                }
        } label: {
            Label("Porchlight", systemImage: viewModel.hasActiveServers ? "lightbulb.fill" : "lightbulb")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(viewModel: viewModel)
                .frame(width: 720, height: 460)
                .task {
                    await viewModel.start()
                }
        }
    }
}
