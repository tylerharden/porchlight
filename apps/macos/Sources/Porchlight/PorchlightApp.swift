import SwiftUI

@main
struct PorchlightApp: App {
    @State private var viewModel = ServerListViewModel()

    var body: some Scene {
        MenuBarExtra {
            NativeMenuBarView(viewModel: viewModel)
        } label: {
            Label("Porchlight", systemImage: viewModel.hasActiveServers ? "lightbulb.fill" : "lightbulb")
                .task {
                    await viewModel.start()
                }
        }

        Settings {
            SettingsView(viewModel: viewModel)
                .frame(width: 720, height: 460)
                .task {
                    await viewModel.start()
                }
        }
    }
}
