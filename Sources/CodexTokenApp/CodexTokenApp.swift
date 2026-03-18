import Cocoa
import SwiftUI

@MainActor
final class CodexTokenAppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = AppPreferences()
    private lazy var viewModel = CodexTokenMenuViewModel(preferences: preferences)

    private var statusBarController: StatusBarController?
    private var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController(viewModel: viewModel, preferences: preferences)
    }

    @IBAction func showSettingsWindow(_ sender: Any?) {
        let controller = settingsWindowController ?? makeSettingsWindowController()
        settingsWindowController = controller

        NSApp.activate(ignoringOtherApps: true)
        if let window = controller.window {
            centerSettingsWindow(window)
        }
        controller.showWindow(sender)
        controller.window?.makeKeyAndOrderFront(sender)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func makeSettingsWindowController() -> NSWindowController {
        let rootView = CodexTokenSettingsView(viewModel: viewModel, preferences: preferences)
        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = preferences.string("menu.settings")
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 920, height: 640)
        centerSettingsWindow(window)

        return NSWindowController(window: window)
    }

    private func centerSettingsWindow(_ window: NSWindow) {
        let visibleFrame = targetVisibleFrame()
        let margin: CGFloat = 48
        let clampedSize = NSSize(
            width: min(window.frame.width, max(760, visibleFrame.width - margin * 2)),
            height: min(window.frame.height, max(560, visibleFrame.height - margin * 2))
        )
        let origin = NSPoint(
            x: visibleFrame.midX - clampedSize.width / 2,
            y: visibleFrame.midY - clampedSize.height / 2
        )
        window.setFrame(NSRect(origin: origin, size: clampedSize), display: false)
    }

    private func targetVisibleFrame() -> NSRect {
        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            return screen.visibleFrame
        }
        return NSScreen.main?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 980, height: 720)
    }
}
