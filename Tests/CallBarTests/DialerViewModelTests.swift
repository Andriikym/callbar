import CallBarCore
import XCTest
@testable import CallBar

final class DialerViewModelTests: XCTestCase {
    @MainActor
    func testButtonFollowsInputValidity() async {
        let model = makeModel()
        XCTAssertFalse(model.canCall)
        XCTAssertNil(model.validationMessage)

        model.rawNumber = "+1 (202) 555-0147"
        XCTAssertTrue(model.canCall)
        XCTAssertEqual(model.normalizedNumber, "+12025550147")

        model.rawNumber = "hello"
        XCTAssertFalse(model.canCall)
        XCTAssertNotNil(model.validationMessage)
    }

    @MainActor
    func testSuccessfulHandoffProducesInformationAndAllowsAnotherAttempt() async {
        let launcher = ControllableLauncher()
        let model = makeModel(launcher: launcher)
        model.rawNumber = "+1 (202) 555-0147"

        await model.call()

        XCTAssertEqual(launcher.requests.first?.number.canonical, "+12025550147")
        XCTAssertEqual(model.notice?.kind, .information)
        XCTAssertTrue(model.notice?.message.contains("+12025550147") == true)
        XCTAssertFalse(model.isOpening)
        XCTAssertTrue(model.canCall)
    }

    @MainActor
    func testFailedHandoffCanBeCorrectedAndRetried() async {
        let launcher = ControllableLauncher()
        launcher.failure = .noHandler
        let model = makeModel(launcher: launcher)
        model.rawNumber = "2025550147"
        await model.call()

        XCTAssertEqual(model.notice?.kind, .error)
        XCTAssertTrue(model.canCall)

        model.rawNumber = "2025550148"
        XCTAssertNil(model.notice)
        launcher.failure = nil
        await model.call()
        XCTAssertEqual(model.notice?.kind, .information)
        XCTAssertEqual(launcher.requests.count, 2)
    }

    @MainActor
    func testProgrammaticInvalidSubmissionDoesNotLaunch() async {
        let launcher = ControllableLauncher()
        let model = makeModel(launcher: launcher)
        model.rawNumber = "123#456"

        await model.call()

        XCTAssertEqual(model.notice?.kind, .error)
        XCTAssertTrue(launcher.requests.isEmpty)
        XCTAssertFalse(model.isOpening)
    }

    @MainActor
    func testSecondSubmissionWhileWaitingIsIgnored() async {
        let entered = expectation(description: "System adapter entered")
        let launcher = ControllableLauncher()
        launcher.shouldWait = true
        launcher.onOpen = { entered.fulfill() }
        let model = makeModel(launcher: launcher)
        model.rawNumber = "2025550147"

        let first = Task { await model.call() }
        await fulfillment(of: [entered], timeout: 2)
        XCTAssertTrue(model.isOpening)
        XCTAssertFalse(model.canCall)

        await model.call()
        XCTAssertEqual(launcher.requests.count, 1)

        launcher.finish()
        await first.value
        XCTAssertFalse(model.isOpening)
        XCTAssertTrue(model.canCall)
    }

    @MainActor
    func testReopeningClearsNoticeButKeepsTheUnpersistedInput() async {
        let model = makeModel()
        model.rawNumber = "2025550147"
        await model.call()
        let previousPresentation = model.presentationID

        model.prepareForPresentation()

        XCTAssertEqual(model.rawNumber, "2025550147")
        XCTAssertNil(model.notice)
        XCTAssertGreaterThan(model.presentationID, previousPresentation)
    }

    @MainActor
    private func makeModel(launcher: ControllableLauncher? = nil) -> DialerViewModel {
        DialerViewModel(dialCall: DialCall(launcher: launcher ?? ControllableLauncher()))
    }
}

@MainActor
private final class ControllableLauncher: CallLaunching {
    var requests: [CallRequest] = []
    var failure: CallLaunchError?
    var shouldWait = false
    var onOpen: (() -> Void)?
    private var continuation: CheckedContinuation<Void, Never>?

    func open(_ request: CallRequest) async throws {
        requests.append(request)
        if shouldWait {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                onOpen?()
            }
        } else {
            onOpen?()
        }
        if let failure {
            throw failure
        }
    }

    func finish() {
        continuation?.resume()
        continuation = nil
    }
}
