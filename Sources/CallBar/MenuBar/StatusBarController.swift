import AppKit

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let model: DialerViewModel
    private var popover: NSPopover?

    init(model: DialerViewModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

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
        if let popover {
            popover.performClose(nil)
            return
        }
        guard let button = statusItem.button else { return }
        NSApplication.shared.activate(ignoringOtherApps: true)
        model.prepareForPresentation()

        let popover = NSPopover()
        let controller = DialerViewController(
            model: model,
            onClose: { [weak popover] in popover?.performClose(nil) }
        )
        popover.contentViewController = controller
        popover.contentSize = DialerViewController.popoverSize
        popover.behavior = .transient
        popover.delegate = self
        self.popover = popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        controller.view.window?.makeKey()
        controller.focusNumber()
    }

    func popoverDidClose(_ notification: Notification) {
        popover = nil
    }
}
