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
            PreferenceRow(label: Strings.Settings.general) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(Strings.Settings.refresh, isOn: $settings.autoRefresh)
                    if settings.autoRefresh {
                        HStack(spacing: 12) {
                            Text(Strings.Settings.every)
                            Stepper("\(Int(settings.refreshInterval)) \(Strings.Settings.seconds)", value: $settings.refreshInterval, in: 1...30, step: 1)
                        }
                        .padding(.leading, 20)
                    }
                    Toggle(Strings.Settings.launchAtLogin, isOn: $settings.launchAtLogin)
                    if let errorMessage = settings.errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                }
            }

            PreferenceRow(label: Strings.Settings.dock) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(Strings.Settings.hideAppIcon, isOn: $settings.hideDockIcon)
                    Text(Strings.Settings.keepOutOfDock)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            PreferenceRow(label: Strings.Settings.menuBar) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(Strings.Settings.hideMenuIcon, isOn: $settings.hideMenuIconWhenEmpty)
                    Text(Strings.Settings.menuBarDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            PreferenceRow(label: Strings.Settings.groups) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(Strings.Settings.showAutomaticGroups, isOn: $settings.showAutomaticGroups)
                    Text(Strings.Settings.automaticGroupsDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Toggle(Strings.Settings.showAppServices, isOn: $settings.showAppServices)
                    Text(Strings.Settings.appServicesDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Toggle(Strings.Settings.showIcons, isOn: $settings.showGroupIcons)
                    Text(Strings.Settings.iconsDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            PreferenceRow(label: Strings.Settings.cli) {
                HStack {
                    Text(Strings.Settings.manageFromTerminal)
                    Spacer()
                    Button(Strings.Settings.showMeHow) { open(readmeURL) }
                }
            }

            Divider()
                .padding(.vertical, 4)

            PreferenceRow(label: Strings.Settings.reset) {
                VStack(alignment: .leading, spacing: 8) {
                    Button(Strings.Settings.resetButton, role: .destructive) {
                        isConfirmingReset = true
                    }
                    .disabled(isResetting)

                    Text(Strings.Settings.resetDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .toggleStyle(.checkbox)
        .confirmationDialog(
            Strings.Settings.resetConfirmation,
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button(Strings.Settings.resetButton, role: .destructive) {
                Task { await resetPorchlight() }
            }
            Button(Strings.Settings.cancel, role: .cancel) {}
        } message: {
            Text(Strings.Settings.resetConfirmationMessage)
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

#if DEBUG
#Preview {
    SettingsTabView(settings: AppSettings())
}
#endif
