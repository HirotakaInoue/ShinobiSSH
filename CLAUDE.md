# CLAUDE.md

This file provides guidance for AI assistants working with the Anchor codebase.

## Project Overview

Anchor is a native macOS menu bar application for managing SSH connections. It monitors running SSH processes, allows one-click connect/disconnect, and persists saved connections to disk.

- **Language**: Swift 5.9+ / SwiftUI
- **Platform**: macOS 13.0 (Ventura) or later
- **UI**: Menu bar popover (`MenuBarExtra` with `.window` style)
- **Config location**: `~/.config/anchor/connections.json`

## Build & Run Commands

### Xcode (recommended)

```bash
brew install xcodegen        # Install XcodeGen (one-time)
xcodegen generate            # Generate Anchor.xcodeproj
open Anchor.xcodeproj        # Open in Xcode, then Cmd+R
```

### Command Line (Swift Package Manager)

```bash
cd Anchor
swift build                  # Debug build
swift build -c release       # Release build → .build/release/Anchor
swift test                   # Run tests (none currently exist)
```

## Project Structure

```
Anchor/
├── AnchorApp.swift                - Entry point, MenuBarExtra setup
├── Package.swift                  - Swift Package Manager config
├── Models/
│   ├── SSHConnection.swift        - Saved connection model (Codable)
│   └── SSHProcess.swift           - Running SSH process model, command parser
├── Services/
│   ├── SSHManager.swift           - Central state (ObservableObject), orchestrates all operations
│   ├── ConnectionStore.swift      - JSON persistence for saved connections
│   └── ProcessMonitor.swift       - SSH process detection (ps), launch (AppleScript), termination
└── Views/
    ├── MenuBarView.swift          - Main popover UI (active/saved/unmatched sections)
    └── AddConnectionView.swift    - Add/edit connection form
```

## Architecture

The app follows an MVVM-like pattern centered around `SSHManager` as the single source of truth:

- **AnchorApp.swift** → Creates `MenuBarExtra` with a window-style popover. Instantiates `SSHManager` as `@StateObject`
- **SSHManager** → `ObservableObject` holding `@Published` state (`savedConnections`, `activeProcesses`, `lastError`). Owns `ConnectionStore` and `ProcessMonitor`. Polls SSH processes every 3 seconds via `Timer`. Process detection runs on a background `DispatchQueue`
- **ConnectionStore** → Reads/writes `[SSHConnection]` to `~/.config/anchor/connections.json`
- **ProcessMonitor** → Executes `ps -eo pid,command` to find SSH processes, parses output into `SSHProcess` structs. Launches SSH via AppleScript (Terminal.app or iTerm). Terminates processes with `SIGTERM`/`SIGKILL`
- **MenuBarView** → Main UI with three sections: Active (matched), Connections (saved), Other SSH (unmatched). Hover reveals action buttons
- **AddConnectionView** → Form for creating/editing connections with live command preview

Data flow: `ProcessMonitor` (detection) → `SSHManager` (state) → `MenuBarView` (render)

## Key Types

- `SSHConnection` (Models/) — Saved connection config: name, host, user, port, identityFile. `Codable` for JSON persistence
- `SSHProcess` (Models/) — Running SSH process: pid, parsed host/user/port from command string. `matchedConnectionID` links to a saved connection
- `SSHManager` (Services/) — Central `ObservableObject`. Manages CRUD for connections, connect/disconnect actions, process monitoring
- `ConnectionStore` (Services/) — JSON file I/O for `[SSHConnection]`
- `ProcessMonitor` (Services/) — System interaction: `ps` parsing, AppleScript SSH launch, process termination

## Dependencies

Swift Package Manager (`Package.swift`):

| Package | Purpose |
|---------|---------|
| (none)  | Uses only Apple frameworks (SwiftUI, Foundation, Combine) |

External tools:

| Tool | Purpose |
|------|---------|
| XcodeGen | Generates `.xcodeproj` from `project.yml` |

## Code Conventions

- **State management**: All mutable state lives in `SSHManager` (`@Published` properties). Views are read-only observers
- **Background work**: Process monitoring runs on a dedicated `DispatchQueue(qos: .utility)`. UI updates dispatch back to main queue
- **Error handling**: Errors surface via `SSHManager.lastError` displayed in the footer
- **Naming**: Swift standard conventions (camelCase properties, PascalCase types)
- **Process detection**: Uses `ps -eo pid,command` and filters for `ssh` executables (excludes sshd, ssh-agent, etc.)
- **SSH launch**: Uses AppleScript to open Terminal.app or iTerm (auto-detected by checking running processes)
- **No async/await**: Uses `DispatchQueue` and `Timer` for concurrency

## Testing

No automated tests currently exist. When adding tests:

- `SSHProcess.parseSSHCommand` is a good candidate for unit tests (pure function, string parsing)
- `ConnectionStore` load/save can be tested with a temp directory
- `SSHManager` business logic (matching processes to connections) is testable with mock data
- UI components are harder to test in isolation

## System Requirements

- macOS 13.0+ (Ventura)
- Xcode 15+ (for building)
- SSH client (pre-installed on macOS)
- Terminal.app or iTerm (for launching SSH sessions)
