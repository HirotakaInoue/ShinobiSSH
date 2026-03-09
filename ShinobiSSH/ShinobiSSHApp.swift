import SwiftUI

@main
struct ShinobiSSHApp: App {
    @StateObject private var manager = SSHManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(manager: manager)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: manager.activeCount > 0
                  ? "terminal.fill"
                  : "terminal")
                .font(.system(size: 12))

            if manager.activeCount > 0 {
                Text("\(manager.activeCount)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
        }
    }
}
