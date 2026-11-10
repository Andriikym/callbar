import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let model: DialerViewModel

    init(model: DialerViewModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        super.init()

        let view = DialerView(
            model: model,
            onClose: { [weak self] in self?.popover.performClose(nil) },
            onQuit: { NSApplication.shared.terminate(nil) }
        )
        popover.contentViewController = NSHostingController(rootView: view)
        popover.contentSize = NSSize(width: 360, height: 400)
        popover.behavior = .transient

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "phone", accessibilityDescription: "CallBar")
            button.image?.isTemplate = true
            button.toolTip = "CallBar — call through iPhone"
            button.setAccessibilityLabel("Open CallBar")
            button.target = self
            button.action = #selector(togglePopover)
        }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let button = statusItem.button else { return }
        NSApplication.shared.activate(ignoringOtherApps: true)
        model.prepareForPresentation()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}
