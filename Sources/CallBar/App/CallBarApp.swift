import AppKit

@main
@MainActor
enum CallBarApp {
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        application.mainMenu = MainMenu.make()
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}
