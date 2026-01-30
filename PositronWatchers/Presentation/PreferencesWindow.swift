import SwiftUI

struct PreferencesView: View {
    @ObservedObject var settings: SettingsStorage
    @State private var newPattern: String = ""
    @State private var editingPattern: ProcessPattern?
    @State private var editingText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Watch Patterns")
                .font(.headline)

            Text("Processes with command lines matching these glob patterns will be monitored.")
                .font(.caption)
                .foregroundColor(.secondary)

            // Pattern list
            List {
                ForEach(settings.patterns) { pattern in
                    PatternRow(
                        pattern: pattern,
                        onToggle: { enabled in
                            settings.updatePattern(id: pattern.id, isEnabled: enabled)
                        },
                        onEdit: {
                            editingPattern = pattern
                            editingText = pattern.pattern
                        },
                        onDelete: {
                            settings.removePattern(id: pattern.id)
                        }
                    )
                    .listRowInsets(EdgeInsets())
                }
            }
            .listStyle(.plain)
            .frame(minHeight: 150)

            // Add new pattern
            HStack {
                TextField("New pattern (e.g., *gulp*watch*)", text: $newPattern)
                    .textFieldStyle(.roundedBorder)

                Button("Add") {
                    addPattern()
                }
                .disabled(newPattern.isEmpty)
            }

            Divider()

            // Launch at login toggle
            Toggle("Launch at Login", isOn: $settings.launchAtLogin)

            Spacer()

            // Reset button
            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                }
            }
        }
        .padding(20)
        .frame(width: 450, height: 380)
        .sheet(item: $editingPattern) { pattern in
            EditPatternSheet(
                pattern: pattern,
                text: $editingText,
                onSave: { newText in
                    settings.updatePattern(id: pattern.id, pattern: newText)
                    editingPattern = nil
                },
                onCancel: {
                    editingPattern = nil
                }
            )
        }
    }

    private func addPattern() {
        let trimmed = newPattern.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        settings.addPattern(trimmed)
        newPattern = ""
    }
}

struct PatternRow: View {
    let pattern: ProcessPattern
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { pattern.isEnabled },
                set: { onToggle($0) }
            ))
            .toggleStyle(.checkbox)

            Text(pattern.pattern)
                .foregroundColor(pattern.isEnabled ? .primary : .secondary)

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
        }
    }
}

struct EditPatternSheet: View {
    let pattern: ProcessPattern
    @Binding var text: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Pattern")
                .font(.headline)

            TextField("Pattern", text: $text)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    onSave(text)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(text.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

#Preview {
    PreferencesView(settings: SettingsStorage())
}
