import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        setupStatusBar()
    }

    private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusBarItem?.button {
            if let image = NSImage(named: "StatusBarIcon") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "Porta"
            }
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover = NSPopover()
        popover?.contentViewController = PopoverContentViewController()
        popover?.behavior = .transient
    }

    @objc func togglePopover(_ sender: Any?) {
        guard let statusBarItem = statusBarItem,
              let button = statusBarItem.button,
              let popover = popover else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

// MARK: - Cursor-capturing popover infrastructure

// Wraps NSHostingController so the root NSView owns a full-coverage NSTrackingArea
// with the .cursorUpdate option. Without this, macOS delivers cursor events to
// whatever window is behind the popover on non-interactive areas.
private final class PopoverContentViewController: NSViewController {
    private let hosting = NSHostingController(rootView: AnyView(ContentView().environmentObject(LanguageManager.shared)))

    override func loadView() {
        view = CursorCapturingView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

private final class CursorCapturingView: NSView {
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.cursorUpdate, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.arrow.set()
    }
}
