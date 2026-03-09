import SwiftUI
import Combine

struct AddConnectionView: View {
    @ObservedObject var manager: SSHManager
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var host: String
    @State private var user: String
    @State private var port: String
    @State private var identityFile: String
    @State private var localForwards: [LocalForward]
    @State private var noRemoteCommand: Bool
    @State private var forceIPv4: Bool
    @State private var showSSHOptions = false
    @State private var showPortForwarding = false

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
        _localForwards = State(initialValue: editing?.localForwards ?? [])
        _noRemoteCommand = State(initialValue: editing?.noRemoteCommand ?? false)
        _forceIPv4 = State(initialValue: editing?.forceIPv4 ?? false)
        _showSSHOptions = State(initialValue: editing?.noRemoteCommand == true || editing?.forceIPv4 == true)
        _showPortForwarding = State(initialValue: !(editing?.localForwards ?? []).isEmpty)
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
                    .onReceive(Just(port)) { newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue {
                            port = filtered
                        }
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

            sshOptionsSection
            portForwardingSection

            if !host.isEmpty {
                previewCommand
            }
        }
        .padding(16)
    }

    // MARK: - SSH Options

    private var sshOptionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            CollapsibleHeader(title: "SSH Options", isExpanded: $showSSHOptions)

            if showSSHOptions {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $noRemoteCommand) {
                        HStack(spacing: 4) {
                            Text("-N")
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.medium)
                            Text("No remote command")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle(isOn: $forceIPv4) {
                        HStack(spacing: 4) {
                            Text("-4")
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.medium)
                            Text("IPv4 only")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
                .padding(.leading, 16)
            }
        }
    }

    // MARK: - Port Forwarding

    private var portForwardingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            CollapsibleHeader(title: "Port Forwarding (-L)", isExpanded: $showPortForwarding)

            if showPortForwarding {
                VStack(spacing: 8) {
                    ForEach(Array(localForwards.enumerated()), id: \.element.id) { index, forward in
                        HStack(spacing: 4) {
                            TextField("Local", text: Binding(
                                get: { String(localForwards[index].localPort) },
                                set: { localForwards[index].localPort = Int($0) ?? 0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)

                            Text(":")
                                .foregroundColor(.secondary)

                            TextField("Remote Host", text: $localForwards[index].remoteHost)
                                .textFieldStyle(.roundedBorder)

                            Text(":")
                                .foregroundColor(.secondary)

                            TextField("Port", text: Binding(
                                get: { String(localForwards[index].remotePort) },
                                set: { localForwards[index].remotePort = Int($0) ?? 0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)

                            Button {
                                localForwards.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .font(.caption)
                    }

                    Button {
                        localForwards.append(LocalForward())
                    } label: {
                        Label("Add Forward", systemImage: "plus.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
                .padding(.leading, 16)
            }
        }
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
                    if let id = editingID,
                       let conn = manager.savedConnections.first(where: { $0.id == id }) {
                        manager.deleteConnection(conn)
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
            identityFile: identityFile.isEmpty ? nil : identityFile,
            localForwards: localForwards,
            noRemoteCommand: noRemoteCommand,
            forceIPv4: forceIPv4
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

        if forceIPv4 {
            parts.append("-4")
        }
        if noRemoteCommand {
            parts.append("-N")
        }
        if !trimmedUser.isEmpty {
            parts.append("-l \(trimmedUser)")
        }
        if let p = Int(port), p != 22 {
            parts.append("-p \(p)")
        }
        if !identityFile.isEmpty {
            parts.append("-i \(identityFile)")
        }
        for forward in localForwards {
            parts.append("-L \(forward.argumentValue)")
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

// MARK: - Collapsible Header

private struct CollapsibleHeader: View {
    let title: String
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                Text(title)
                    .font(.caption)
                Spacer()
            }
            .foregroundColor(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
