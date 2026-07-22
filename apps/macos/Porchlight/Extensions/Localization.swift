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
    
    static func localised(_ enUS: String, _ enAU: String) -> String {
        switch current {
        case .enUS: enUS
        case .enAU: enAU
        }
    }
}

struct Strings {
    static let customise: String = Language.localised("Customize", "Customise")
    static let colour: String = Language.localised("Color", "Colour")
    
    struct TabNavigation {
        static let servers: String = "Servers"
        static let groups: String = "Groups"
        static let settings: String = "Settings"
        static let about: String = "About"
    }
    
    struct GroupDetail {
        static let showGroupServers: String = "Show Group Servers"
        static let hideGroupServers: String = "Hide Group Servers"
        static let deleteGroup: String = "Delete Group"
        static let nameLabel: String = "Name"
        static let colourLabel: String = Strings.colour
        static let colourPlaceholder: String = "#34C759"
        static let iconLabel: String = "Icon"
        static let iconPlaceholder: String = "Auto-detect, /path/to/favicon.ico, or file:// URL"
        static let iconHelpText: String = "Leave blank to auto-detect common project favicons from matching working directories."
        static let commandContainsLabel: String = "Command Contains"
        static let commandContainsPlaceholder: String = "manage.py runserver"
        static let workingDirectoryLabel: String = "Working Directory"
        static let workingDirectoryPlaceholder: String = "~/Developer/ausmusicfinder"
        static let priorityLabel: String = "Priority"
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
    
    struct ServerDetail {
        static let pin: String = "Pin"
        static let unpin: String = "Unpin"
        static let stop: String = "Stop"
        static let remove: String = "Remove"
        static let hide: String = "Hide"
        static let open: String = "Open"
        static let openInFinder: String = "Open in Finder"
        static let openInApp: String = "Open in App"
        static let visualStudioCode: String = "Visual Studio Code"
        static let xcode: String = "Xcode"
    }
    
    struct ServerList {
        static let serversHeader: String = "Servers"
        static let loadingServers: String = "Loading Servers"
        static let noServers: String = "No Servers"
        static let noServersDescription: String = "Start a local development server and it will appear here."
        static let showHidden: String = "Show Hidden"
        static let loadingDetails: String = "Loading Details"
        static let selectServer: String = "Select a Server"
        static let selectServerDescription: String = "Choose a port to see details."
        static let unhide: String = "Unhide"
        static let turnOff: String = "Turn Off"
        static let turnOn: String = "Turn On"
    }
    
    struct GroupsList {
        static let groupsHeader: String = "Groups"
        static let hidden: String = "Hidden"
        static let loadingGroups: String = "Loading Groups"
        static let noGroups: String = "No Groups"
        static let noGroupsDescription: String = "Create a group or let Porchlight discover active groups automatically."
        static let selectGroup: String = "Select a Group"
        static let selectGroupDescription: String = "Groups match servers without changing their type."
    }
    
    struct GroupRow {
        static let manual: String = "Manual"
        static let auto: String = "Auto"
    }
    
    struct StatusMenu {
        static let cliFailed: String = "Porchlight CLI failed"
        static let noServersRunning: String = "No local servers running"
        static let refresh: String = "Refresh"
        static let killAll: String = "Kill All"
        static let openPorchlight: String = "Open Porchlight"
        static let quitPorchlight: String = "Quit Porchlight"
        static let openInFinder: String = "Open in Finder"
        static let command: String = "Command"
        static let copyCommand: String = "Copy Command"
        static let start: String = "Start"
        static let kill: String = "Kill"
        static let killAndRemove: String = "Kill and Remove"
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
        static let appServicesDescription: String = "When disabled, hides background listeners from other apps running on your Mac."
        static let showIcons: String = "Show icons"
        static let iconsDescription: String = "When disabled, group icons won't be shown in the list."
        static let cli: String = "CLI:"
        static let manageFromTerminal: String = "Manage Porchlight from the Terminal."
        static let showMeHow: String = "Show me how"
        static let reset: String = "Reset:"
        static let resetButton: String = "Reset Porchlight to Defaults"
        static let resetDescription: String = "Removes saved server history, pins, groups, classification rules, and settings."
        static let every: String = "Every"
        static let seconds: String = "seconds"
        static let resetConfirmation: String = "Reset Porchlight to defaults?"
        static let resetConfirmationMessage: String = "This removes saved server history, pins, groups, classification rules, and Porchlight settings."
        static let cancel: String = "Cancel"
    }
    
    struct About {
        static let appName: String = "Porchlight"
        static let tagline: String = "Find the servers you left on."
        static let description: String = "Porchlight runs locally and uses the bundled Rust CLI to inspect development servers."
        static let acknowledgementsLink: String = "Acknowledgements"
        static let privacyPolicyLink: String = "Privacy Policy"
        static let termsOfUseLink: String = "Terms of Use"
        static let reportIssue: String = "Report an Issue..."
        static let checkForUpdates: String = "Check for Updates..."
        static let copyright: String = "© 2026 Porchlight. All rights reserved."
    }
}
