import SwiftUI

@main
struct ShinobiSSHApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let manager = SSHManager()
    private var cancellable: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusBarIcon()

        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .applicationDefined
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(manager: manager)
        )

        if let button = statusItem.button {
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.action = #selector(statusItemClicked)
            button.target = self
        }

        // Update menu bar icon when active count changes
        cancellable = manager.$activeProcesses
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusBarIcon()
            }
    }

    private func updateStatusBarIcon() {
        guard let button = statusItem.button else { return }

        let iconName = manager.activeCount > 0 ? "terminal.fill" : "terminal"
        let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "ShinobiSSH")
        image?.isTemplate = true
        button.image = image

        if manager.activeCount > 0 {
            button.title = " \(manager.activeCount)"
        } else {
            button.title = ""
        }
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit ShinobiSSH", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - NSPopoverDelegate

    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        // Prevent popover from closing when NSOpenPanel or other modal is active
        if let _ = NSApp.modalWindow {
            return false
        }
        return true
    }
}
