import SwiftUI

@main
struct PorchlightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var viewModel = ServerListViewModel()

    var body: some Scene {
        Settings {
            SettingsView(viewModel: viewModel)
                .frame(width: 720, height: 460)
                .task {
                    await viewModel.start()
                }
        }
    }
}
