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
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center, spacing: 10) {
                        GroupIconView(icon: icon.wrappedValue, color: color.wrappedValue, size: 16)
                        Text(name.wrappedValue)
                            .font(.title2.weight(.semibold))
                    }

                    Divider()

                    DetailEditorRow(label: "Name") {
                        TextField("Group name", text: name)
                            .textFieldStyle(.roundedBorder)
                    }

                    DetailEditorRow(label: "Colour") {
                        HStack {
                            ColorPicker("", selection: colorBinding(color))
                                .labelsHidden()
                            TextField("#34C759", text: color)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }
                    }

                    DetailEditorRow(label: "Icon") {
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Auto-detect, /path/to/favicon.ico, or file:// URL", text: optionalStringBinding(icon))
                                .textFieldStyle(.roundedBorder)
                            Text("Leave blank to auto-detect common project favicons from matching working directories.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
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

                    Divider()

                    Button("Delete Group", role: .destructive) {
                        store.deleteGroup(id: groupID)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            CompactEmptyState(title: "Group Not Found", systemImage: "folder.badge.questionmark")
        }
    }

    private func colorBinding(_ hex: Binding<String>) -> Binding<Color> {
        Binding(
            get: { Color(hex: hex.wrappedValue) },
            set: { hex.wrappedValue = $0.hexString }
        )
    }

    private func optionalStringBinding(_ value: Binding<String?>) -> Binding<String> {
        Binding(
            get: { value.wrappedValue ?? "" },
            set: { value.wrappedValue = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        )
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
