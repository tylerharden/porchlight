import Foundation

enum Language {
    case enUS
    case enAU
    
    static var current: Language {
        let locale = Locale.current
        if let languageCode = locale.language.languageCode?.identifier {
            if languageCode == "en" {
                let regionCode = locale.region?.identifier ?? ""
                if regionCode == "AU" {
                    return .enAU
                }
            }
        }
        return .enUS
    }
}

struct Strings {
    static let customise: String = {
        switch Language.current {
        case .enUS:
            return "Customize"
        case .enAU:
            return "Customise"
        }
    }()
    
    struct GroupDetail {
        static let showGroupServers: String = "Show Group Servers"
        static let hideGroupServers: String = "Hide Group Servers"
        static let deleteGroup: String = "Delete Group"
        static let kind: String = "Kind"
        static let role: String = "Role"
        static let activeServers: String = "Active Servers"
        static let recentServers: String = "Recent Servers"
        static let activations: String = "Activations"
        static let firstSeen: String = "First Seen"
        static let lastSeen: String = "Last Seen"
        static let unknown: String = "Unknown"
        static let service: String = "Service"
        static let groupNotFound: String = "Group Not Found"
    }
    
    struct Settings {
        static let general: String = "General:"
        static let refresh: String = "Refresh server list"
        static let launchAtLogin: String = "Launch Porchlight at login"
        static let dock: String = "Dock:"
        static let hideAppIcon: String = "Hide app icon when all windows are closed"
        static let keepOutOfDock: String = "Keep Porchlight out of the Dock when you're not using it."
        static let menuBar: String = "Menu Bar:"
        static let hideMenuIcon: String = "Hide app icon when no servers are active"
        static let menuBarDescription: String = "Keep Porchlight quiet until there is something useful to show."
        static let groups: String = "Groups:"
        static let showAutomaticGroups: String = "Show automatic groups"
        static let automaticGroupsDescription: String = "When disabled, only groups you create manually are shown."
        static let showAppServices: String = "Show app services"
        static let appServicesDescription: String = "When disabled, hides background listeners from apps like Adobe Creative Cloud and Ableton."
        static let showIcons: String = "Show icons"
        static let iconsDescription: String = "When disabled, group icons won't be shown in the list."
        static let cli: String = "CLI:"
        static let manageFromTerminal: String = "Manage Porchlight from the Terminal."
        static let showMeHow: String = "Show me how"
        static let reset: String = "Reset:"
        static let resetButton: String = "Reset Porchlight to Defaults"
        static let resetDescription: String = "Removes saved server history, pins, groups, classification rules, and settings."
    }
}
