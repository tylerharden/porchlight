import AppKit
import SwiftUI

struct SettingsTabView: View {
    @Bindable var settings: AppSettings
    @State private var groupStore = ServerGroupStore()
    @State private var isConfirmingReset = false
    @State private var isResetting = false
    private let readmeURL = URL(string: "https://github.com/tylerharden/porchlight#readme")!

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PreferenceRow(label: "General:") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Refresh server list", isOn: $settings.autoRefresh)
                    if settings.autoRefresh {
                        HStack(spacing: 12) {
                            Text("Every")
                            Stepper("\(Int(settings.refreshInterval)) seconds", value: $settings.refreshInterval, in: 1...30, step: 1)
                        }
                        .padding(.leading, 20)
                    }
                    Toggle("Launch Porchlight at login", isOn: $settings.launchAtLogin)
                    if let errorMessage = settings.errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                }
            }

            PreferenceRow(label: "Dock:") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Hide icon when all windows are closed", isOn: $settings.hideDockIcon)
                    Text("Keep Porchlight out of the Dock when you're not using it.")
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

    private func resetPorchlight() async {
        guard !isResetting else { return }
        isResetting = true
        defer { isResetting = false }

        await settings.resetToDefaults()
        await groupStore.load()
    }

    private func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

#Preview {
    SettingsTabView(settings: AppSettings())
}

struct PreferenceRow<Content: View>: View {
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

struct LinkButton: View {
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
