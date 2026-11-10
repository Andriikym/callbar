import AppKit
import CallBarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let launcher = SystemCallLauncher()
        let model = DialerViewModel(dialCall: DialCall(launcher: launcher))
        statusBarController = StatusBarController(model: model)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
