import SwiftUI

struct GroupDetailView: View {
    let groupID: ServerGroup.ID
    @Bindable var store: ServerGroupStore
    @State private var commandText = ""
    @State private var directoryText = ""

    var body: some View {
        if
            let name = store.binding(for: groupID, keyPath: \.name),
            let color = store.binding(for: groupID, keyPath: \.color),
            let icon = store.binding(for: groupID, keyPath: \.icon),
            let priority = store.binding(for: groupID, keyPath: \.priority),
            let group = store.groups.first(where: { $0.id == groupID })
        {
            let summary = store.summaries.first { $0.id == groupID }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center, spacing: 10) {
                        GroupIconView(icon: icon.wrappedValue, color: color.wrappedValue, size: 16)
                        Text(name.wrappedValue)
                            .font(.title2.weight(.semibold))
                    }

                    HStack(spacing: 8) {
                        Button(summary?.hidden == true ? "Show Group Servers" : "Hide Group Servers") {
                            Task { await store.setGroupHidden(id: groupID, hidden: !(summary?.hidden ?? false)) }
                        }

                        Button("Delete Group", role: .destructive) {
                            store.deleteGroup(id: groupID)
                        }
                    }

                    Divider()

                    DetailEditorRow(label: "Name") {
                        TextField("Group name", text: name)
                            .textFieldStyle(.roundedBorder)
                    }

                    DetailEditorRow(label: "Colour") {
                        HStack(spacing: 10) {
                            Toggle("", isOn: colorEnabledBinding(color))
                                .labelsHidden()

                            if !color.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                ColorPicker("", selection: colorBinding(color))
                                    .labelsHidden()
                                TextField("#34C759", text: color)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                            }
                        }
                    }

                    DetailEditorRow(label: "Icon") {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Toggle("", isOn: iconEnabledBinding(icon))
                                .labelsHidden()

                            if icon.wrappedValue != nil {
                                VStack(alignment: .leading, spacing: 6) {
                                    TextField("Auto-detect, /path/to/favicon.ico, or file:// URL", text: optionalStringBinding(icon))
                                        .textFieldStyle(.roundedBorder)
                                    Text("Leave blank to auto-detect common project favicons from matching working directories.")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    DetailEditorRow(label: "Command Contains") {
                        ChipEditor(
                            placeholder: "manage.py runserver",
                            text: $commandText,
                            values: group.commandContains,
                            add: { store.addCommand(commandText, to: groupID); commandText = "" },
                            remove: { store.removeCommand($0, from: groupID) }
                        )
                    }

                    DetailEditorRow(label: "Working Directory") {
                        ChipEditor(
                            placeholder: "/Users/tyler/Developer/ausmusicfinder",
                            text: $directoryText,
                            values: group.workingDirectories,
                            add: { store.addWorkingDirectory(directoryText, to: groupID); directoryText = "" },
                            remove: { store.removeWorkingDirectory($0, from: groupID) }
                        )
                    }

                    DetailEditorRow(label: "Priority") {
                        Stepper(value: priority, in: 0...1000, step: 10) {
                            Text(priority.wrappedValue.formatted())
                        }
                    }

                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            if let summary = store.summaries.first(where: { $0.id == groupID }) {
                AutomaticGroupDetailView(
                    summary: summary,
                    customize: { await store.promoteGroup(id: summary.id) },
                    toggleHidden: { await store.setGroupHidden(id: summary.id, hidden: !summary.hidden) }
                )
            } else {
                CompactEmptyState(title: "Group Not Found", systemImage: "folder.badge.questionmark")
            }
        }
    }

    private func colorBinding(_ hex: Binding<String>) -> Binding<Color> {
        Binding(
            get: { Color(hex: hex.wrappedValue) },
            set: { hex.wrappedValue = $0.hexString }
        )
    }

    private func colorEnabledBinding(_ color: Binding<String>) -> Binding<Bool> {
        Binding(
            get: { !color.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            set: { isEnabled in color.wrappedValue = isEnabled ? "#34C759" : "" }
        )
    }

    private func iconEnabledBinding(_ icon: Binding<String?>) -> Binding<Bool> {
        Binding(
            get: { icon.wrappedValue != nil },
            set: { isEnabled in icon.wrappedValue = isEnabled ? "" : nil }
        )
    }

    private func optionalStringBinding(_ value: Binding<String?>) -> Binding<String> {
        Binding(
            get: { value.wrappedValue ?? "" },
            set: { value.wrappedValue = $0 }
        )
    }
}

struct AutomaticGroupDetailView: View {
    let summary: GroupSummary
    let customize: () async -> Void
    let toggleHidden: () async -> Void
    @State private var isCustomizing = false
    @State private var isTogglingHidden = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center, spacing: 10) {
                        GroupIconView(icon: summary.icon, color: summary.color ?? "#8E8E93", size: 16)
                        VStack(alignment: .leading, spacing: 2) {
                        Text(summary.name)
                            .font(.title2.weight(.semibold))
                        Text("Automatic Group")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        if summary.hidden {
                            Text("Hidden")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.secondary)
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Button(summary.hidden ? "Show Group Servers" : "Hide Group Servers") {
                            guard !isTogglingHidden else { return }
                            isTogglingHidden = true
                            Task {
                                await toggleHidden()
                                isTogglingHidden = false
                            }
                        }
                        .disabled(isTogglingHidden)

                        Button("Customize") {
                            guard !isCustomizing else { return }
                            isCustomizing = true
                            Task {
                                await customize()
                                isCustomizing = false
                            }
                        }
                        .disabled(isCustomizing)
                    }

                    Text("Customize saves this discovered group as a manual group, then lets you edit its name, colour, icon, and match rules.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Divider()

                SummaryRow(label: "Kind", value: summary.kind ?? "Unknown")
                SummaryRow(label: "Role", value: summary.role ?? "Service")
                SummaryRow(label: "Active Servers", value: summary.activeServerCount.formatted())
                SummaryRow(label: "Recent Servers", value: summary.recentServerCount.formatted())
                SummaryRow(label: "Activations", value: summary.activeCount.formatted())
                if let firstSeenText = summary.firstSeenText {
                    SummaryRow(label: "First Seen", value: firstSeenText)
                }
                if let lastSeenText = summary.lastSeenText {
                    SummaryRow(label: "Last Seen", value: lastSeenText)
                }
                SummaryRow(label: "Source", value: summary.reason ?? summary.source)

                if !summary.ports.isEmpty {
                    SummaryRow(label: "Ports", value: summary.ports.map(String.init).joined(separator: ", "))
                }

                if !summary.paths.isEmpty {
                    DetailEditorRow(label: "Paths") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(summary.paths, id: \.self) { path in
                                Text(path)
                                    .textSelection(.enabled)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        DetailEditorRow(label: label) {
            Text(value)
                .textSelection(.enabled)
        }
    }
}

struct ChipEditor: View {
    let placeholder: String
    @Binding var text: String
    let values: [String]
    let add: () -> Void
    let remove: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addIfNeeded)
                Button("Add", action: addIfNeeded)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if values.isEmpty {
                Text("No values yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(values, id: \.self) { value in
                        HStack(spacing: 6) {
                            Text(value)
                                .textSelection(.enabled)
                                .lineLimit(1)
                            Button {
                                remove(value)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
                    }
                }
            }
        }
    }

    private func addIfNeeded() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        add()
    }
}

struct DetailEditorRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .trailing)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    let store = ServerGroupStore()
    store.groups = [
        ServerGroup(
            id: "g1", name: "Frontend", color: "#007AFF",
            icon: nil,
            commandContains: ["next dev", "vite"],
            workingDirectories: ["/Users/tyler/Developer/myapp"],
            priority: 100
        )
    ]
    return GroupDetailView(groupID: "g1", store: store)
        .frame(width: 460, height: 480)
}
