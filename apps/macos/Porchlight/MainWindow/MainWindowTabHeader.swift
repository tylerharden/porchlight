import AppKit
import SwiftUI

struct MainWindowTabHeader: View {
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

// MARK: - Helper Views

enum PorchlightTab: String, CaseIterable, Identifiable {
    case servers = "Servers"
    case groups = "Groups"
    case settings = "Settings"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .servers: "lightbulb"
        case .groups: "folder"
        case .settings: "slider.horizontal.3"
        case .about: "info.circle"
        }
    }
}

struct TabButton: View {
    let tab: PorchlightTab
    @Binding var selectedTab: PorchlightTab

    var body: some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                if tab == .servers {
                    Image(nsImage: PorchlightStatusIcon.image(isActive: false))
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: tab.icon)
                        .font(.title3)
                }
                Text(tab.rawValue)
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(minWidth: 72, minHeight: 52)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
            .background {
                if selectedTab == tab {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.quaternary, lineWidth: 1)
                        }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview {
    MainWindowTabHeader(selectedTab: .constant(.servers))
}
#endif
