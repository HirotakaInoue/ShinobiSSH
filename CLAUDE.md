# CLAUDE.md

This file provides guidance for AI assistants working with the Anchor codebase.

## Project Overview

Anchor is a Terminal User Interface (TUI) tool written in Rust for managing ports and SSH tunnels on macOS. It uses `lsof` for port detection, `ssh` for tunneling, and `ratatui`/`crossterm` for the terminal interface.

- **Language**: Rust (Edition 2024)
- **Platform**: macOS only (relies on `lsof` and macOS-specific command output)
- **Config location**: `~/.config/anchor/tunnels.json`

## Build & Run Commands

```bash
cargo build                # Debug build
cargo build --release      # Optimized release build (LTO + strip)
cargo run                  # Run in debug mode
cargo clippy               # Lint checks
cargo fmt                  # Format code
cargo fmt -- --check       # Check formatting without modifying
cargo test                 # Run tests (none currently exist)
```

Install after building:
```bash
cp target/release/anchor /usr/local/bin/
```

## Project Structure

```
src/
├── main.rs    - Entry point, terminal setup, event loop (crossterm events)
├── app.rs     - Application state (App struct), business logic, input handling
├── ui.rs      - TUI rendering with ratatui (tables, dialogs, layout)
├── port.rs    - Port detection via lsof parsing (PortInfo struct)
└── tunnel.rs  - SSH tunnel management and JSON persistence (TunnelConfig, TunnelManager)
```

## Architecture

The app follows a single-threaded event loop with clear separation of concerns:

- **main.rs** → Sets up the terminal, runs a 250ms polling event loop, dispatches keyboard events to `app.rs`, calls `ui::draw()` each frame
- **app.rs** → Central state container (`App` struct). Holds all UI state (current tab, selection index, dialogs) and data (ports list, tunnel manager). All state mutations happen here
- **ui.rs** → Pure rendering layer. Reads `App` state and draws to the terminal frame. No state mutations
- **port.rs** → Executes `lsof` to discover TCP/UDP ports, parses output into `PortInfo` structs
- **tunnel.rs** → Manages SSH tunnel lifecycle (connect/disconnect via subprocess), persists config to JSON

Data flow: `main.rs` (events) → `app.rs` (state mutation) → `ui.rs` (render)

## Key Types

- `App` (app.rs) — Main state container with ports, tunnels, tab state, dialogs
- `AppTab` (app.rs) — Enum: `Ports`, `Tunnels`
- `InputMode` (app.rs) — Multi-step tunnel creation dialog state
- `PendingAction` (app.rs) — Confirmation dialog actions (kill process, delete tunnel)
- `PortInfo` (port.rs) — Parsed port entry (port, pid, process, protocol, state, address)
- `TunnelConfig` (tunnel.rs) — Individual tunnel config, serialized to JSON
- `TunnelManager` (tunnel.rs) — Collection of tunnels with load/save to disk

## Dependencies

| Crate | Purpose |
|-------|---------|
| `ratatui` 0.29 | TUI framework (widgets, layout, styling) |
| `crossterm` 0.29 | Terminal control (raw mode, events, alternate screen) |
| `anyhow` 1.0 | Error handling with `Result<T>` propagation |
| `serde` 1.0 | Serialization/deserialization (derive macros) |
| `serde_json` 1.0 | JSON persistence for tunnel configs |
| `dirs` 6.0 | Platform-specific config directory resolution |
| `tokio` 1.48 | Async runtime (included but not actively used) |

## Code Conventions

- **Error handling**: Use `anyhow::Result<T>` with `?` propagation. Surface errors to users via the status bar message
- **Naming**: snake_case for functions/variables, PascalCase for types/enums
- **Module size**: Keep modules focused and under ~350 lines
- **State management**: All mutable state lives in `App` struct. UI layer is read-only
- **Serde**: Use `#[serde(skip)]` for non-persistent fields (e.g., process PIDs)
- **External commands**: Execute via `std::process::Command`, parse stdout
- **No async**: Despite tokio dependency, the codebase uses synchronous/blocking operations

## Testing

No automated tests currently exist. When adding tests:

- Use Rust's built-in `#[cfg(test)]` module pattern within each source file
- Port parsing logic in `port.rs` is a good candidate for unit tests
- Tunnel config serialization in `tunnel.rs` is testable without system dependencies
- UI rendering and event loop are harder to test in isolation

## System Requirements

- macOS (uses `lsof -iTCP -iUDP -nP` for port detection)
- SSH client (for tunnel management)
- Rust 1.70+ toolchain
