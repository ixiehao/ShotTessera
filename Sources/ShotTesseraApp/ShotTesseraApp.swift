import AppKit
import SwiftUI

private enum ProjectLinks {
    static let repository = URL(string: "https://github.com/ixiehao/ShotTessera")!
    static let issues = URL(string: "https://github.com/ixiehao/ShotTessera/issues/new/choose")!
}

private enum AboutCredits {
    static func make(language: AppLanguage) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.paragraphSpacing = 5

        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph
        ]
        let linkAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.linkColor,
            .paragraphStyle: paragraph,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        let credits = NSMutableAttributedString()

        func appendBody(_ text: String) {
            credits.append(NSAttributedString(string: text, attributes: bodyAttributes))
        }

        func appendLink(_ text: String, destination: URL) {
            var attributes = linkAttributes
            attributes[.link] = destination
            credits.append(NSAttributedString(string: text, attributes: attributes))
        }

        appendBody("\(language.text("about.developer")) · xao\n")
        appendLink("github.com/ixiehao/ShotTessera\n", destination: ProjectLinks.repository)
        appendLink(language.text("about.feedback"), destination: ProjectLinks.issues)
        appendBody("\n\n\(language.text("about.privacy"))\n\(language.text("about.license"))")
        return credits
    }
}

private struct HelpStep: View {
    let index: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Text(index)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
                .background(Color.accentColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct HelpPanel: View {
    let language: AppLanguage

    private func t(_ key: String) -> String {
        language.text(key)
    }

    private var icon: NSImage {
        if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
           let image = NSImage(contentsOf: iconURL) {
            return image
        }
        return NSApplication.shared.applicationIconImage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("help.title"))
                        .font(.system(size: 18, weight: .bold))
                    Text(t("help.intro"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                HelpStep(index: "1", title: t("help.step.add.title"), detail: t("help.step.add.detail"))
                HelpStep(index: "2", title: t("help.step.settings.title"), detail: t("help.step.settings.detail"))
                HelpStep(index: "3", title: t("help.step.create.title"), detail: t("help.step.create.detail"))
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text(t("help.troubleshoot.title"))
                    .font(.system(size: 13, weight: .semibold))
                Text(t("help.troubleshoot.detail"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(t("help.privacy"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Link(t("help.project"), destination: ProjectLinks.repository)
                    .buttonStyle(.bordered)
                Link(t("help.feedback"), destination: ProjectLinks.issues)
                    .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}

/// SwiftUI creates the window, while AppKit handles the macOS Dock lifecycle.
/// In particular, a Dock click after miniaturising the only window must bring
/// that existing window back instead of leaving the application active but
/// invisible.
final class ShotTesseraAppDelegate: NSObject, NSApplicationDelegate {
    private var helpWindow: NSWindow?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return true }
        Task { @MainActor [weak self] in
            self?.restoreMainWindow(in: sender)
        }
        return true
    }

    @MainActor
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

    @MainActor
    func showAboutPanel(language: AppLanguage) {
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .credits: AboutCredits.make(language: language)
        ])
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @MainActor
    func showHelpPanel(language: AppLanguage) {
        let window: NSWindow
        if let existingWindow = helpWindow {
            window = existingWindow
        } else {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 460),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.center()
            helpWindow = window
        }

        window.title = language.text("help.title")
        window.contentView = NSHostingView(rootView: HelpPanel(language: language))
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

@main
struct ShotTesseraApp: App {
    @NSApplicationDelegateAdaptor(ShotTesseraAppDelegate.self) private var appDelegate
    @AppStorage("appLanguage") private var languageCode = AppLanguage.chinese.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .chinese
    }

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
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(language.text("about.menu")) {
                    appDelegate.showAboutPanel(language: language)
                }
            }

            CommandGroup(replacing: .help) {
                Button(language.text("help.menu")) {
                    appDelegate.showHelpPanel(language: language)
                }
                Divider()
                Button(language.text("help.project")) {
                    NSWorkspace.shared.open(ProjectLinks.repository)
                }
                Button(language.text("help.feedback")) {
                    NSWorkspace.shared.open(ProjectLinks.issues)
                }
            }
        }
    }
}
