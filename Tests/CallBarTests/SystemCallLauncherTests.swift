import AppKit
import CallBarCore
import XCTest
@testable import CallBar

final class SystemCallLauncherTests: XCTestCase {
    @MainActor
    func testMissingHandlerDoesNotAttemptToOpenTheURL() async throws {
        let workspace = StubWorkspace()
        workspace.handlerURL = nil
        let request = try CallRequest(rawNumber: "+1 (202) 555-0147")

        do {
            try await SystemCallLauncher(workspace: workspace).open(request)
            XCTFail("A missing handler must be reported")
        } catch {
            XCTAssertEqual(error as? CallLaunchError, .noHandler)
        }

        XCTAssertEqual(workspace.lookupURLs, [request.url])
        XCTAssertTrue(workspace.openedURLs.isEmpty)
    }

    @MainActor
    func testRejectedOpenIsReportedAsAFailure() async throws {
        let workspace = StubWorkspace()
        workspace.openResult = false
        let request = try CallRequest(rawNumber: "020 7946 0958")

        do {
            try await SystemCallLauncher(workspace: workspace).open(request)
            XCTFail("A rejected open must not be reported as a handoff")
        } catch {
            XCTAssertEqual(error as? CallLaunchError, .openFailed)
        }

        XCTAssertEqual(workspace.lookupURLs, [request.url])
        XCTAssertEqual(workspace.openedURLs, [request.url])
    }

    @MainActor
    func testSuccessfulOpenUsesTheCanonicalTelephoneURLExactlyOnce() async throws {
        let workspace = StubWorkspace()
        let request = try CallRequest(rawNumber: "+1 (202) 555-0147")

        try await SystemCallLauncher(workspace: workspace).open(request)

        XCTAssertEqual(workspace.lookupURLs.map(\.absoluteString), ["tel:+12025550147"])
        XCTAssertEqual(workspace.openedURLs.map(\.absoluteString), ["tel:+12025550147"])
    }
}

// Neither override calls super: tests must never reach the user's phone handler.
private final class StubWorkspace: NSWorkspace {
    var handlerURL: URL? = URL(fileURLWithPath: "/Applications/TestPhoneHandler.app")
    var openResult = true
    private(set) var lookupURLs: [URL] = []
    private(set) var openedURLs: [URL] = []

    override func urlForApplication(toOpen url: URL) -> URL? {
        lookupURLs.append(url)
        return handlerURL
    }

    override func open(_ url: URL) -> Bool {
        openedURLs.append(url)
        return openResult
    }
}
