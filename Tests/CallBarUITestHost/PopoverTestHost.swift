import AppKit
import CallBarCore

@MainActor
private final class StubLauncher: CallLaunching {
    func open(_ request: CallRequest) async throws {
        fatalError("Browsing or using list actions unexpectedly initiated a handoff.")
    }
}

@main
@MainActor
final class PopoverTestHost: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var model: DialerViewModel!
    private var popover: NSPopover?

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.mainMenu = MainMenu.make()
        let delegate = PopoverTestHost()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let path = ProcessInfo.processInfo.environment["CALLBAR_UI_TEST_STORAGE"] else {
            fatalError("The UI tests must provide an isolated storage directory.")
        }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        let lists = SavedCalls(directory: directory)
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try seed(lists)
            } catch {
                fatalError("Could not create the UI test fixture: \(error)")
            }
        }
        model = DialerViewModel(dialCall: DialCall(launcher: StubLauncher()), lists: lists)

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 525),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "CallBar Popover Test Host"
        window.center()
        window.makeKeyAndOrderFront(nil)
        openPopover()
    }

    private func seed(_ lists: SavedCalls) throws {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        for index in 0..<14 {
            let number = String(format: "55501%02d", index)
            try lists.saveFavorite(id: nil, name: "Sample \(index + 1)", rawNumber: number)
            let attempt = lists.startAttempt(number: number, at: index < 7 ? yesterday : today)
            lists.finishAttempt(attempt, with: index.isMultiple(of: 2) ? .sent : .openFailed)
        }
    }

    private func openPopover() {
        guard let anchor = window.contentView else { return }
        model.prepareForPresentation()
        let popover = NSPopover()
        let controller = DialerViewController(model: model) { [weak popover] in popover?.performClose(nil) }
        popover.contentViewController = controller
        popover.contentSize = DialerViewController.popoverSize
        // Keep the fixture open if the desktop changes focus between XCTest events.
        popover.behavior = .applicationDefined
        self.popover = popover
        let positioningRect = NSRect(x: anchor.bounds.midX - 60, y: anchor.bounds.maxY - 45, width: 120, height: 24)
        popover.show(relativeTo: positioningRect, of: anchor, preferredEdge: .minY)
        controller.view.window?.makeKey()
        controller.focusNumber()
    }
}
