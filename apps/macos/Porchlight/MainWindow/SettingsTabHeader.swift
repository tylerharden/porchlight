import SwiftUI

struct SettingsTabHeader: View {
    @Binding var selectedTab: PorchlightTab

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                TabButton(tab: .servers, selectedTab: $selectedTab)
                TabButton(tab: .groups, selectedTab: $selectedTab)
                TabButton(tab: .settings, selectedTab: $selectedTab)
                TabButton(tab: .about, selectedTab: $selectedTab)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

#Preview {
    SettingsTabHeader(selectedTab: .constant(.servers))
}
