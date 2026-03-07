import SwiftUI

struct AddConnectionView: View {
    @ObservedObject var manager: SSHManager
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var host: String
    @State private var user: String
    @State private var port: String
    @State private var identityFile: String

    private let editingID: UUID?
    private let isEditing: Bool

    init(manager: SSHManager, editing: SSHConnection? = nil) {
        self.manager = manager
        self.editingID = editing?.id
        self.isEditing = editing != nil
        _name = State(initialValue: editing?.name ?? "")
        _host = State(initialValue: editing?.host ?? "")
        _user = State(initialValue: editing?.user ?? "")
        _port = State(initialValue: String(editing?.port ?? 22))
        _identityFile = State(initialValue: editing?.identityFile ?? "")
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && !host.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            formContent
            Divider()
            footer
        }
        .frame(width: 360)
    }

    private var header: some View {
        HStack {
            Text(isEditing ? "Edit Connection" : "New Connection")
                .font(.headline)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    private var formContent: some View {
        VStack(spacing: 12) {
            FormField(label: "Name", placeholder: "My Server", text: $name)
            FormField(label: "Host", placeholder: "example.com", text: $host)
            FormField(label: "User", placeholder: "root (optional)", text: $user)

            HStack(alignment: .top) {
                Text("Port")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .trailing)
                TextField("22", text: $port)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .onChange(of: port) { newValue in
                        port = newValue.filter { $0.isNumber }
                    }
                Spacer()
            }

            HStack(alignment: .top) {
                Text("Key File")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .trailing)

                HStack(spacing: 4) {
                    TextField("~/.ssh/id_rsa (optional)", text: $identityFile)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        selectKeyFile()
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.bordered)
                }
            }

            if !host.isEmpty {
                previewCommand
            }
        }
        .padding(16)
    }

    private var previewCommand: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Command Preview")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(buildPreviewCommand())
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary.opacity(0.7))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(6)
        }
    }

    private var footer: some View {
        HStack {
            if isEditing {
                Button("Delete", role: .destructive) {
                    if let id = editingID {
                        manager.savedConnections.removeAll { $0.id == id }
                    }
                    dismiss()
                }
            }

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button(isEditing ? "Save" : "Add") {
                save()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!isValid)
        }
        .padding(16)
    }

    private func save() {
        let connection = SSHConnection(
            id: editingID ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            host: host.trimmingCharacters(in: .whitespaces),
            user: user.trimmingCharacters(in: .whitespaces),
            port: Int(port) ?? 22,
            identityFile: identityFile.isEmpty ? nil : identityFile
        )

        if isEditing {
            manager.updateConnection(connection)
        } else {
            manager.addConnection(connection)
        }

        dismiss()
    }

    private func buildPreviewCommand() -> String {
        var parts = ["ssh"]
        let trimmedUser = user.trimmingCharacters(in: .whitespaces)
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)

        if !trimmedUser.isEmpty {
            parts.append("-l \(trimmedUser)")
        }
        if let p = Int(port), p != 22 {
            parts.append("-p \(p)")
        }
        if !identityFile.isEmpty {
            parts.append("-i \(identityFile)")
        }
        parts.append(trimmedHost)
        return parts.joined(separator: " ")
    }

    private func selectKeyFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh")
        panel.showsHiddenFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            identityFile = url.path
        }
    }
}

// MARK: - Form Field Component

private struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}
