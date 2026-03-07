import SwiftUI

struct MenuBarView: View {
    @ObservedObject var manager: SSHManager
    @State private var showingAddSheet = false
    @State private var editingConnection: SSHConnection?
    @State private var registeringProcess: SSHProcess?
    @State private var registerName = ""
    @State private var confirmDisconnectAll = false

    var body: some View {
        VStack(spacing: 0) {
            if !manager.activeProcesses.isEmpty {
                activeSection
            }

            if !manager.savedConnections.isEmpty {
                if !manager.activeProcesses.isEmpty {
                    sectionDivider
                }
                savedSection
            }

            if !manager.unmatchedProcesses.isEmpty {
                sectionDivider
                unmatchedSection
            }

            if manager.activeProcesses.isEmpty && manager.savedConnections.isEmpty {
                emptyState
            }

            sectionDivider
            footerSection
        }
        .frame(width: 320)
        .sheet(isPresented: $showingAddSheet) {
            AddConnectionView(manager: manager)
        }
        .sheet(item: $editingConnection) { connection in
            AddConnectionView(manager: manager, editing: connection)
        }
        .alert("Register Connection", isPresented: Binding(
            get: { registeringProcess != nil },
            set: { if !$0 { registeringProcess = nil } }
        )) {
            TextField("Connection Name", text: $registerName)
            Button("Register") {
                if let process = registeringProcess {
                    manager.registerProcess(process, name: registerName)
                }
                registeringProcess = nil
                registerName = ""
            }
            Button("Cancel", role: .cancel) {
                registeringProcess = nil
                registerName = ""
            }
        } message: {
            if let process = registeringProcess {
                Text("Save \(process.displayName) as a connection?")
            }
        }
        .alert("Disconnect All", isPresented: $confirmDisconnectAll) {
            Button("Disconnect All", role: .destructive) {
                manager.disconnectAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Terminate all \(manager.activeCount) SSH connections?")
        }
    }

    // MARK: - Active Connections

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(
                title: "Active",
                count: manager.activeCount,
                color: .green
            ) {
                if manager.activeCount > 1 {
                    Button {
                        confirmDisconnectAll = true
                    } label: {
                        Text("End All")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(activeRows, id: \.process.id) { row in
                ActiveConnectionRow(
                    name: row.name,
                    detail: row.detail,
                    onDisconnect: {
                        manager.disconnect(process: row.process)
                    }
                )
            }
        }
    }

    private var activeRows: [(name: String, detail: String, process: SSHProcess)] {
        manager.activeProcesses.map { process in
            if let connID = process.matchedConnectionID,
               let conn = manager.savedConnections.first(where: { $0.id == connID }) {
                return (name: conn.name, detail: conn.displayHost, process: process)
            } else {
                return (name: process.displayName, detail: "PID: \(process.pid)", process: process)
            }
        }
    }

    // MARK: - Saved Connections

    private var savedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "Connections", count: nil, color: .secondary)

            ForEach(manager.savedConnections) { connection in
                SavedConnectionRow(
                    connection: connection,
                    isConnected: manager.isConnected(connection),
                    onConnect: { manager.connect(connection) },
                    onDisconnect: {
                        if let process = manager.processFor(connection) {
                            manager.disconnect(process: process)
                        }
                    },
                    onEdit: { editingConnection = connection },
                    onDelete: { manager.deleteConnection(connection) }
                )
            }
        }
    }

    // MARK: - Unmatched SSH Processes

    private var unmatchedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "Other SSH", count: manager.unmatchedProcesses.count, color: .orange)

            ForEach(manager.unmatchedProcesses) { process in
                UnmatchedProcessRow(
                    process: process,
                    onDisconnect: { manager.disconnect(process: process) },
                    onRegister: {
                        registerName = process.displayName
                        registeringProcess = process
                    }
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "network.slash")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("No SSH Connections")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Add a connection to get started")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Button {
                showingAddSheet = true
            } label: {
                Label("New", systemImage: "plus")
                    .font(.caption)
            }
            .buttonStyle(.plain)

            Spacer()

            if let error = manager.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(1)
                Spacer()
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func sectionHeader(
        title: String,
        count: Int?,
        color: Color,
        @ViewBuilder trailing: () -> some View = { EmptyView() }
    ) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            if let count = count {
                Text("(\(count))")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var sectionDivider: some View {
        Divider()
            .padding(.horizontal, 12)
    }
}

// MARK: - Active Connection Row

struct ActiveConnectionRow: View {
    let name: String
    let detail: String
    let onDisconnect: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(.body, design: .default))
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovering {
                Button(action: onDisconnect) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovering ? Color.primary.opacity(0.05) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Saved Connection Row

struct SavedConnectionRow: View {
    let connection: SSHConnection
    let isConnected: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovering = false
    @State private var showConfirmDelete = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isConnected ? .green : Color.secondary.opacity(0.3))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(connection.name)
                    .font(.system(.body, design: .default))
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(connection.displayHost)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovering {
                HStack(spacing: 4) {
                    if isConnected {
                        Button(action: onDisconnect) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: onConnect) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.plain)
                    }

                    Menu {
                        if isConnected {
                            Button("Disconnect", action: onDisconnect)
                        } else {
                            Button("Connect", action: onConnect)
                        }
                        Divider()
                        Button("Edit...", action: onEdit)
                        Divider()
                        Button("Delete", role: .destructive) {
                            showConfirmDelete = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 20)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovering ? Color.primary.opacity(0.05) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .alert("Delete Connection", isPresented: $showConfirmDelete) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete \"\(connection.name)\"? This cannot be undone.")
        }
    }
}

// MARK: - Unmatched Process Row

struct UnmatchedProcessRow: View {
    let process: SSHProcess
    let onDisconnect: () -> Void
    let onRegister: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.orange)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(process.displayName)
                    .font(.system(.body, design: .default))
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text("PID: \(process.pid)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovering {
                HStack(spacing: 4) {
                    Button(action: onRegister) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Save as connection")

                    Button(action: onDisconnect) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Terminate")
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovering ? Color.primary.opacity(0.05) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
