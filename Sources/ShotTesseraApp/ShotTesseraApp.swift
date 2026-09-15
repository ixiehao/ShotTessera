import AppKit
import SwiftUI

/// SwiftUI creates the window, while AppKit handles the macOS Dock lifecycle.
/// In particular, a Dock click after miniaturising the only window must bring
/// that existing window back instead of leaving the application active but
/// invisible.
final class ShotTesseraAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return true }
        restoreMainWindow(in: sender)
        return true
    }

    private func restoreMainWindow(in application: NSApplication) {
        guard let window = application.windows.first(where: { $0.contentView != nil }) else {
            application.activate(ignoringOtherApps: true)
            return
        }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        application.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

@main
struct ShotTesseraApp: App {
    @NSApplicationDelegateAdaptor(ShotTesseraAppDelegate.self) private var appDelegate

    init() {
        if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 940, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}
