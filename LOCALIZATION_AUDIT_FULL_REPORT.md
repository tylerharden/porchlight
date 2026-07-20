# Porchlight macOS App - Comprehensive Localization Audit

## Executive Summary
Comprehensive search completed of all Swift files in `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/` to identify hardcoded user-facing strings. Found **100+ user-facing strings**, approximately **60+ new strings** that need to be added to `Localization.swift`.

---

## Files Analyzed (30 Swift files)

### Main Window Components
1. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/MainWindow/MainWindowView.swift`
2. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/MainWindow/MainWindowTabHeader.swift`
3. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/MainWindow/SettingsTabView.swift`
4. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/MainWindow/AboutTabView.swift`
5. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/MainWindow/ServerDetailView.swift`
6. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/MainWindow/GroupDetailView.swift`
7. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/MainWindow/ServerListView.swift`
8. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/MainWindow/GroupsListView.swift`
9. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/MainWindow/ServerRowView.swift`
10. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/MainWindow/GroupRowView.swift`
11. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/MainWindow/CompactEmptyState.swift`

### Menu Bar Components
12. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/MenuBar/StatusMenuBuilder.swift`
13. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/MenuBar/ServerMenuItemView.swift`
14. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/MenuBar/StartMenuItemView.swift`
15. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/MenuBar/RefreshMenuItemView.swift`

### App Controllers & Services
16. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/App/AppDelegate.swift`
17. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/App/SettingsWindowController.swift`
18. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/App/StatusBarController.swift`
19. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/Services/PorchlightCLI.swift`

### View Models
20. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/ViewModels/ServerListViewModel.swift`

### Models
21. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/Models/AppSettings.swift`
22. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/Models/LocalServer.swift`
23. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/Models/PorchlightAppIcon.swift`
24. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/Models/PorchlightStatusIcon.swift`
25. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/Models/ServerGroup.swift`

### Shared Views
26. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/SharedViews/GroupIconView.swift`
27. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/SharedViews/PreviewSupport.swift`

### Extensions (Existing)
28. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/Extensions/Localization.swift`
29. `/Users/tyler/Developer/porchlight/apps/macos/Porchlight/Extensions/NSColor+Hex.swift`

---

## New Strings by Category

### 1. Tab Navigation (4 strings)
**File:** MainWindowTabHeader.swift (lines 23-27)
```
"Servers", "Groups", "Settings", "About"
```

### 2. Settings Tab (4 new strings)
**File:** SettingsTabView.swift (lines 18, 19, 95, 99, 102, 104)
```
"Every", "seconds"
"Reset Porchlight to defaults?"
"This removes saved server history, pins, groups, classification rules, and Porchlight settings."
"Reset Porchlight", "Cancel"
```

### 3. About Tab (9 strings)
**File:** AboutTabView.swift (lines 18-46)
```
"Porchlight" (app name)
"Version 0.1.0"
"Find the servers you left on."
"Acknowledgements", "Privacy Policy", "Terms of Use"
"Report an Issue..."
"Porchlight runs locally and uses the bundled Rust CLI to inspect development servers."
"© 2026 Porchlight. All rights reserved."
```

### 4. Server Detail View (18 strings)
**File:** ServerDetailView.swift (lines 24, 27, 50-69, 81-92, 98-113)
```
Buttons: "Pin", "Unpin", "Stop", "Stop and Remove", "Start", "Remove", "Hide", "Open", "Open in Finder"
Menus: "Open in App", "Visual Studio Code", "Xcode"
Labels: "Status", "Group", "Group Kind", "URL", "Process", "Path", "Command", "Last Seen", "Start Command"
Help Text: "Stop the running process", "Stop the process and remove it from Porchlight", "No start command is available", "Run the saved start command", "Remove this server from Porchlight", "Hide this server from normal lists"
```

### 5. Group Detail View (15 strings)
**File:** GroupDetailView.swift (lines 27, 38-98, 162-208, 257-262)
```
Labels: "Name", "Colour"/"Color", "Icon", "Command Contains", "Working Directory", "Priority"
Placeholders: "#34C759", "Auto-detect, /path/to/favicon.ico, or file:// URL", "manage.py runserver", "~/Developer/ausmusicfinder"
Help Text: "Leave blank to auto-detect common project favicons from matching working directories."
Auto Group: "Automatic Group", "Hidden", "Source", "Ports", "Paths"
Chip Editor: "Add", "No values yet."
```

### 6. Server List View (13 strings)
**File:** ServerListView.swift (lines 28, 62-96, 130-162)
```
Headers: "Servers", "Loading Servers", "No Servers", "Show Hidden"
Descriptions: "Start a local development server and it will appear here.", "Loading Details", "Select a Server", "Choose a port to see details."
Swipe Actions: "Unhide", "Turn Off", "Turn On", "Unpin", "Hide"
Dynamic: "%d Active" (format string)
```

### 7. Groups List View (9 strings)
**File:** GroupsListView.swift (lines 35-79)
```
Headers: "Groups", "Hidden"
States: "Loading Groups", "No Groups", "Loading Details", "Select a Group"
Description: "Create a group or let Porchlight discover active groups automatically.", "Groups match servers without changing their type."
```

### 8. Group Row View (2 strings)
**File:** GroupRowView.swift (lines 13, 25)
```
"Manual", "Auto"
```

### 9. Status Menu Bar (19 strings)
**File:** StatusMenuBuilder.swift (lines 58-204)
```
Error/Empty: "Porchlight CLI failed", "No local servers running"
Menu Items: "Refresh", "Kill All", "Open Porchlight", "Quit Porchlight"
Submenus: "Open in Finder", "Open in App", "Visual Studio Code", "Xcode", "Command", "Copy Command"
Actions: "Start", "Kill", "Kill and Remove", "Remove", "Hide", "Pin", "Unpin"
```

### 10. App Menu (2 strings)
**File:** AppDelegate.swift (lines 49, 55)
```
"Show Porchlight", "Quit Porchlight"
```

### 11. Error Messages (2 strings)
**File:** PorchlightCLI.swift (lines 174, 150)
```
"Missing porchlight CLI at {path}. Run `cargo build` in the cli folder."
"Unknown CLI error"
```

---

## Strings Already in Localization.swift

The following strings are **already properly localized**:
- `Strings.customise` (with US/AU variants: "Customize" / "Customise")
- `Strings.GroupDetail` struct with 13 entries
- `Strings.Settings` struct with 21 entries

---

## Recommended Structure for New Entries

```swift
struct Strings {
    static let customise: String = { /* ... existing ... */ }()
    
    struct GroupDetail {
        // Existing entries
        static let showGroupServers: String = "Show Group Servers"
        static let hideGroupServers: String = "Hide Group Servers"
        // ... other existing entries ...
        
        // NEW ENTRIES
        static let nameLabel: String = "Name"
        static let colourLabel: String = {
            switch Language.current {
            case .enUS: return "Color"
            case .enAU: return "Colour"
            }
        }()
        // ... more new entries organized by functionality
    }
    
    // NEW STRUCTS
    struct TabNavigation { ... }
    struct ServerDetail { ... }
    struct ServerList { ... }
    struct GroupsList { ... }
    struct StatusMenu { ... }
    struct AboutTab { ... }
    struct AppMenu { ... }
    struct Errors { ... }
}
```

---

## Implementation Checklist

- [ ] Create `Strings.TabNavigation` struct (4 strings)
- [ ] Expand `Strings.GroupDetail` with new label/placeholder strings (12 strings)
- [ ] Create `Strings.ServerDetail` struct (18 strings)
- [ ] Create `Strings.ServerList` struct (13 strings)
- [ ] Create `Strings.GroupsList` struct (9 strings)
- [ ] Create `Strings.GroupRow` struct (2 strings)
- [ ] Create `Strings.StatusMenu` struct (19 strings)
- [ ] Create `Strings.SettingsTab` struct (4 new strings)
- [ ] Create `Strings.AboutTab` struct (9 strings)
- [ ] Create `Strings.AppMenu` struct (2 strings)
- [ ] Create `Strings.Errors` struct (2 strings)
- [ ] Add Color/Colour language variant to GroupDetail (already done for Customize/Customise)
- [ ] Update all Swift files to use `Strings.*` instead of hardcoded strings
- [ ] Test localization with both enUS and enAU language settings

---

## Quick Reference: Strings by File

| File | New Strings | Status |
|------|-------------|--------|
| MainWindowTabHeader.swift | 4 | High Priority |
| SettingsTabView.swift | 4 | High Priority |
| AboutTabView.swift | 9 | Medium Priority |
| ServerDetailView.swift | 18 | High Priority |
| GroupDetailView.swift | 15 | High Priority |
| ServerListView.swift | 13 | High Priority |
| GroupsListView.swift | 9 | Medium Priority |
| GroupRowView.swift | 2 | Low Priority |
| StatusMenuBuilder.swift | 19 | High Priority |
| AppDelegate.swift | 2 | Low Priority |
| PorchlightCLI.swift | 2 | Medium Priority |
| **TOTAL** | **97** | |

---

## Notes

- All strings identified are **user-facing** UI text
- Excluded: URLs, file paths, JSON keys, code identifiers, comments, format specifiers
- Placeholders retained for context (e.g., example email, example path)
- Dynamic strings handled with format strings (e.g., "%d Active")
- Language variants maintained for US/AU English differences
- Status bar menu items frequently reference the same action strings (consolidated in StatusMenu struct)

