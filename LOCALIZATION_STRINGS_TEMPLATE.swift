// COMPREHENSIVE LIST OF NEW STRINGS TO ADD TO Localization.swift
// Organized by component for easy reference

struct Strings {
    // Existing...
    static let customise: String = { /* ... */ }()
    
    // NEW SECTIONS
    
    struct TabNavigation {
        static let servers: String = "Servers"
        static let groups: String = "Groups"
        static let settings: String = "Settings"
        static let about: String = "About"
    }
    
    struct ServerDetail {
        static let pinButton: String = "Pin"
        static let unpinButton: String = "Unpin"
        static let pinHelpText: String = "Pin"
        static let unpinHelpText: String = "Unpin"
        
        static let stopButton: String = "Stop"
        static let stopHelpText: String = "Stop the running process"
        static let stopAndRemoveButton: String = "Stop and Remove"
        static let stopAndRemoveHelpText: String = "Stop the process and remove it from Porchlight"
        
        static let startButton: String = "Start"
        static let noStartCommandHelp: String = "No start command is available"
        static let startCommandHelp: String = "Run the saved start command"
        
        static let removeButton: String = "Remove"
        static let removeHelpText: String = "Remove this server from Porchlight"
        
        static let hideButton: String = "Hide"
        static let hideHelpText: String = "Hide this server from normal lists"
        
        static let openButton: String = "Open"
        static let openInFinderButton: String = "Open in Finder"
        static let openInAppMenu: String = "Open in App"
        static let visualStudioCode: String = "Visual Studio Code"
        static let xcodeApp: String = "Xcode"
        
        // Detail row labels
        static let statusLabel: String = "Status"
        static let groupLabel: String = "Group"
        static let groupKindLabel: String = "Group Kind"
        static let urlLabel: String = "URL"
        static let processLabel: String = "Process"
        static let pathLabel: String = "Path"
        static let commandLabel: String = "Command"
        static let lastSeenLabel: String = "Last Seen"
        static let startCommandLabel: String = "Start Command"
    }
    
    struct GroupDetail {
        static let nameLabel: String = "Name"
        
        static let colourLabel: String = {
            switch Language.current {
            case .enUS:
                return "Color"
            case .enAU:
                return "Colour"
            }
        }()
        
        static let colourPlaceholder: String = "#34C759"
        static let iconLabel: String = "Icon"
        static let iconPlaceholder: String = "Auto-detect, /path/to/favicon.ico, or file:// URL"
        static let iconHelpText: String = "Leave blank to auto-detect common project favicons from matching working directories."
        
        static let commandContainsLabel: String = "Command Contains"
        static let commandContainsPlaceholder: String = "manage.py runserver"
        
        static let workingDirectoryLabel: String = "Working Directory"
        static let workingDirectoryPlaceholder: String = "~/Developer/ausmusicfinder"
        
        static let priorityLabel: String = "Priority"
        
        // Automatic group details
        static let automaticGroupLabel: String = "Automatic Group"
        static let hiddenLabel: String = "Hidden"
        static let sourceLabel: String = "Source"
        static let portsLabel: String = "Ports"
        static let pathsLabel: String = "Paths"
        
        // Chip editor
        static let addButton: String = "Add"
        static let noValuesYetMessage: String = "No values yet."
    }
    
    struct ServerList {
        static let activeServerCount: String = {
            // Format: "X Active" where X is dynamic
            // Use as: String(format: Strings.ServerList.activeServerCountFormat, count)
            return "%d Active"
        }()
        
        static let serversHeader: String = "Servers"
        static let loadingServersTitle: String = "Loading Servers"
        static let noServersTitle: String = "No Servers"
        static let noServersDescription: String = "Start a local development server and it will appear here."
        
        static let showHiddenSection: String = "Show Hidden"
        static let loadingDetailsTitle: String = "Loading Details"
        static let selectServerTitle: String = "Select a Server"
        static let selectServerDescription: String = "Choose a port to see details."
        
        // Swipe actions
        static let unhideAction: String = "Unhide"
        static let turnOffAction: String = "Turn Off"
        static let turnOnAction: String = "Turn On"
        static let unpinAction: String = "Unpin"
        static let hideAction: String = "Hide"
    }
    
    struct GroupsList {
        static let groupsHeader: String = "Groups"
        static let hiddenSection: String = "Hidden"
        static let loadingGroupsTitle: String = "Loading Groups"
        static let noGroupsTitle: String = "No Groups"
        static let noGroupsDescription: String = "Create a group or let Porchlight discover active groups automatically."
        static let loadingDetailsTitle: String = "Loading Details"
        static let selectGroupTitle: String = "Select a Group"
        static let selectGroupDescription: String = "Groups match servers without changing their type."
    }
    
    struct GroupRow {
        static let manualBadge: String = "Manual"
        static let autoBadge: String = "Auto"
    }
    
    struct StatusMenu {
        // Error states
        static let cliFailedMessage: String = "Porchlight CLI failed"
        static let noServersRunning: String = "No local servers running"
        
        // Menu items
        static let refreshMenuItem: String = "Refresh"
        static let killAllMenuItem: String = "Kill All"
        static let openPorchlightMenuItem: String = "Open Porchlight"
        static let quitPorchlightMenuItem: String = "Quit Porchlight"
        
        // Submenu items
        static let openInFinderMenuItem: String = "Open in Finder"
        static let openInAppSubmenu: String = "Open in App"
        static let visualStudioCodeOption: String = "Visual Studio Code"
        static let xcodeOption: String = "Xcode"
        
        static let commandSubmenu: String = "Command"
        static let copyCommandAction: String = "Copy Command"
        
        // Server actions
        static let startAction: String = "Start"
        static let killAction: String = "Kill"
        static let killAndRemoveAction: String = "Kill and Remove"
        static let removeAction: String = "Remove"
        static let hideAction: String = "Hide"
        static let pinToggle: String = "Pin"
        static let unpinToggle: String = "Unpin"
    }
    
    struct SettingsTab {
        // New strings not already in Settings struct
        static let everyLabel: String = "Every"
        static let secondsLabel: String = "seconds"
        
        static let resetConfirmationTitle: String = "Reset Porchlight to defaults?"
        static let resetConfirmationMessage: String = "This removes saved server history, pins, groups, classification rules, and Porchlight settings."
        static let resetConfirmButton: String = "Reset Porchlight"
        static let cancelButton: String = "Cancel"
    }
    
    struct AboutTab {
        static let appName: String = "Porchlight"
        static let versionString: String = "Version 0.1.0"
        static let tagline: String = "Find the servers you left on."
        
        static let acknowledgementsLink: String = "Acknowledgements"
        static let privacyPolicyLink: String = "Privacy Policy"
        static let termsOfUseLink: String = "Terms of Use"
        
        static let reportIssueButton: String = "Report an Issue..."
        
        static let descriptionText: String = "Porchlight runs locally and uses the bundled Rust CLI to inspect development servers."
        static let copyrightText: String = "© 2026 Porchlight. All rights reserved."
    }
    
    struct AppMenu {
        static let showPorchlight: String = "Show Porchlight"
        static let quitPorchlight: String = "Quit Porchlight"
    }
    
    struct Errors {
        static let missingCLIError: String = "Missing porchlight CLI at %@. Run `cargo build` in the cli folder."
        static let unknownCLIError: String = "Unknown CLI error"
    }
    
    // Existing GroupDetail struct can be expanded...
    struct GroupDetail {
        // Already has: showGroupServers, hideGroupServers, deleteGroup, kind, role, activeServers, etc.
        // Add the new ones above
    }
    
    struct Settings {
        // Already complete with existing entries
        // Add new ones above in SettingsTab
    }
}
