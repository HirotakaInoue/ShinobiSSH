# ShinobiSSH

A native macOS menu bar application for managing SSH connections.

![Platform](https://img.shields.io/badge/platform-macOS%2013+-blue.svg)
![Swift](https://img.shields.io/badge/swift-5.9+-orange.svg)

## Features

- **Menu Bar Integration** - Lives in the macOS menu bar with minimal footprint. Shows active connection count at a glance.
- **Connection Management** - Register SSH connections with custom names for quick access.
- **Real-time Monitoring** - Automatically detects all running SSH processes every 3 seconds.
- **One-click Connect/Disconnect** - Launch SSH sessions in Terminal.app or iTerm. Terminate with a single click.
- **Unregistered SSH Detection** - Detects SSH connections started outside of ShinobiSSH and allows managing or saving them.
- **Persistent Storage** - Saved connections persist across app restarts in `~/.config/shinobishsh/connections.json`.

## Menu Bar UX

| State | Menu Bar |
|-------|----------|
| No active SSH | `⬜ terminal icon` |
| 3 active SSH | `◼ terminal icon` **3** |

The popover displays three sections:

- **Active** - Currently connected SSH sessions with disconnect buttons
- **Connections** - Saved connections with connect/disconnect and edit actions
- **Other SSH** - Unregistered SSH processes detected on the system, with options to terminate or save

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15+ (for building)
- SSH client (pre-installed on macOS)

## Build

### Option 1: Xcode

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen):
   ```bash
   brew install xcodegen
   ```

2. Generate the Xcode project and open it (run from the repository root):
   ```bash
   xcodegen generate
   open ShinobiSSH.xcodeproj
   ```

3. Build and run (Cmd+R) in Xcode.

### Option 2: Command Line

1. Move into the Swift package directory:
   ```bash
   cd ShinobiSSH
   ```

2. Build:
   ```bash
   swift build -c release
   ```

The binary will be at `ShinobiSSH/.build/release/ShinobiSSH`.

## Usage

1. Launch ShinobiSSH - it appears as a terminal icon in the menu bar.
2. Click the icon to open the popover.
3. Click **+ New** to register an SSH connection.
4. Click the play button or use the context menu to connect.
5. Active connections show a green indicator. Hover to reveal disconnect button.
6. Unregistered SSH processes appear in the "Other SSH" section and can be saved or terminated.

## Configuration

Connections are stored in:

```
~/.config/shinobishsh/connections.json
```

Each connection stores:

| Field | Description |
|-------|-------------|
| `name` | Display name (e.g., "Production DB") |
| `host` | SSH server hostname |
| `user` | SSH username (optional) |
| `port` | SSH port (default: 22) |
| `identityFile` | Path to SSH key (optional) |

## License

MIT
