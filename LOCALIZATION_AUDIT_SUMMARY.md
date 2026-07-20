# Porchlight macOS App - Hardcoded Strings Search Complete

## Search Results Summary

I've conducted a comprehensive search of all Swift files in the Porchlight macOS app (`apps/macos/Porchlight/`) to identify hardcoded user-facing strings that should be localized.

### Key Findings

**Total Files Analyzed:** 30 Swift files  
**Total User-Facing Strings Found:** 100+  
**New Strings to Add to Localization:** 97  
**Strings Already Localized:** 37 (in existing Localization.swift)

### Breakdown by Component

| Component | File | New Strings | Priority |
|-----------|------|-------------|----------|
| Tab Navigation | MainWindowTabHeader.swift | 4 | High |
| Settings Tab | SettingsTabView.swift | 6 | High |
| About Tab | AboutTabView.swift | 9 | Medium |
| Server Details | ServerDetailView.swift | 18 | High |
| Group Details | GroupDetailView.swift | 15 | High |
| Server List | ServerListView.swift | 13 | High |
| Groups List | GroupsListView.swift | 9 | Medium |
| Group Row | GroupRowView.swift | 2 | Low |
| Status Menu | StatusMenuBuilder.swift | 19 | High |
| App Menu | AppDelegate.swift | 2 | Low |
| Errors | PorchlightCLI.swift | 2 | Medium |
| **TOTAL** | | **97** | |

### New String Categories

1. **Tab Navigation** (4) - Servers, Groups, Settings, About
2. **Button Labels** (28) - Pin/Unpin, Start, Stop, Remove, Hide, Open, etc.
3. **Help Text & Tooltips** (12) - Descriptions for button actions
4. **Detail Labels** (18) - Status, Group, URL, Process, Path, Command, etc.
5. **Section Headers** (13) - List/table section titles
6. **Empty States** (8) - Loading states and "no items" messages
7. **Menu Items** (19) - Status bar menu actions
8. **Form Fields** (10) - Input placeholders and labels
9. **App Information** (9) - Version, tagline, links, copyright
10. **Error Messages** (2) - Error handling text

### Files with Hardcoded Strings

High Priority (Core UI):
- MainWindowTabHeader.swift
- SettingsTabView.swift
- ServerDetailView.swift
- GroupDetailView.swift
- ServerListView.swift
- StatusMenuBuilder.swift

Medium Priority (Supporting UI):
- AboutTabView.swift
- GroupsListView.swift
- PorchlightCLI.swift

Low Priority (Labels/Badges):
- GroupRowView.swift
- AppDelegate.swift

### Notable Patterns Found

1. **Conditional Strings**: Pin/Unpin, Show/Hide buttons that change text based on state
2. **Dynamic Strings**: "\(count) Active" needs format string approach
3. **Language Variants**: "Colour"/"Color" needs US/AU English variants (like existing "Customize"/"Customise")
4. **Help Text**: Button help/tooltip text scattered throughout detail views
5. **Menu Items**: Status bar menu has significant string duplication with detail views

### Recommended Implementation

1. Create nested structs in `Localization.swift`:
   - `Strings.TabNavigation`
   - `Strings.ServerDetail`
   - `Strings.GroupDetail` (expand existing)
   - `Strings.ServerList`
   - `Strings.GroupsList`
   - `Strings.StatusMenu`
   - `Strings.AboutTab`
   - `Strings.AppMenu`
   - `Strings.Errors`

2. Add language variant for Color/Colour following existing Customize/Customise pattern

3. Use format strings for dynamic content (e.g., "%d Active")

4. Replace hardcoded strings in views with `Strings.*` references

### Files Generated

I've created detailed analysis files showing:
1. Complete string lists organized by component
2. Exact file paths and line numbers for each string
3. Swift code structure recommendations
4. Implementation checklist
5. Quick reference tables

All files are available at:
- `/tmp/porchlight_strings_analysis.md` - Detailed component-by-component analysis
- `/tmp/porchlight_localization_final_report.md` - Full report with recommendations
- `/tmp/new_localization_strings.swift` - Swift code structure template
- `/tmp/HARDCODED_STRINGS_REFERENCE.txt` - Quick reference with line numbers
- `/tmp/SUMMARY.md` - This summary

### Next Steps

1. Review the string lists and organization structure
2. Copy recommendations into Localization.swift
3. Update view files to use `Strings.*` instead of hardcoded strings
4. Test localization with both enUS and enAU language settings
5. Add more languages as needed (following the existing Language enum pattern)

---

**Search completed successfully with comprehensive documentation.**
