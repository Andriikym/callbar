import AppKit
import CallBarCore

@MainActor
final class SystemCallLauncher: CallLaunching {
    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    func open(_ request: CallRequest) async throws {
        guard workspace.urlForApplication(toOpen: request.url) != nil else {
            throw CallLaunchError.noHandler
        }
        guard workspace.open(request.url) else {
            throw CallLaunchError.openFailed
        }
    }
}
