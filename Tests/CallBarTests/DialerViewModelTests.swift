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
    func testClearingNumberResetsDialerAfterHandoff() async {
        let model = makeModel()
        model.rawNumber = "+1 (202) 555-0147"
        await model.call()
        XCTAssertNotNil(model.notice)
        XCTAssertTrue(model.canCall)

        model.clearNumber()

        XCTAssertTrue(model.rawNumber.isEmpty)
        XCTAssertNil(model.normalizedNumber)
        XCTAssertNil(model.validationMessage)
        XCTAssertNil(model.notice)
        XCTAssertFalse(model.canCall)
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
    func testEditingAndPresentingNeverStartACall() async {
        let launcher = ControllableLauncher()
        let model = makeModel(launcher: launcher)

        model.prepareForPresentation()
        model.rawNumber = "+1 (202) 555-0147"
        model.prepareForPresentation()
        model.rawNumber = "invalid"
        model.rawNumber = "2025550148"

        XCTAssertTrue(launcher.requests.isEmpty)
        XCTAssertFalse(model.isOpening)
        XCTAssertTrue(model.canCall)
        XCTAssertNil(model.notice)
    }

    @MainActor
    func testEditingAfterSuccessClearsTheNoticeAndRevalidates() async {
        let launcher = ControllableLauncher()
        let model = makeModel(launcher: launcher)
        model.rawNumber = "2025550147"
        await model.call()
        XCTAssertEqual(model.notice?.kind, .information)

        model.rawNumber = "12"
        XCTAssertNil(model.notice)
        XCTAssertNil(model.normalizedNumber)
        XCTAssertNotNil(model.validationMessage)
        XCTAssertFalse(model.canCall)

        model.rawNumber = " \t\n"
        XCTAssertNil(model.validationMessage)
        XCTAssertFalse(model.canCall)

        model.rawNumber = "020 7946 0958"
        XCTAssertNil(model.validationMessage)
        XCTAssertEqual(model.normalizedNumber, "02079460958")
        XCTAssertTrue(model.canCall)
        XCTAssertEqual(launcher.requests.count, 1)
    }

    @MainActor
    func testEachSystemFailureCanBeRetriedWithoutEditingTheNumber() async {
        for failure in [CallLaunchError.noHandler, .openFailed] {
            let launcher = ControllableLauncher()
            launcher.failure = failure
            let model = makeModel(launcher: launcher)
            model.rawNumber = "2025550147"

            await model.call()
            XCTAssertEqual(model.notice?.kind, .error)
            XCTAssertEqual(model.notice?.message, failure.localizedDescription)
            XCTAssertFalse(model.isOpening)
            XCTAssertTrue(model.canCall)

            launcher.failure = nil
            await model.call()
            XCTAssertEqual(model.notice?.kind, .information)
            XCTAssertFalse(model.isOpening)
            XCTAssertEqual(launcher.requests.count, 2)
            XCTAssertEqual(launcher.requests.first, launcher.requests.last)
        }
    }

    @MainActor
    func testReopeningDuringHandoffKeepsDuplicateProtectionUntilFailure() async {
        let entered = expectation(description: "System adapter entered")
        let launcher = ControllableLauncher()
        launcher.shouldWait = true
        launcher.failure = .openFailed
        launcher.onOpen = { entered.fulfill() }
        let model = makeModel(launcher: launcher)
        model.rawNumber = "2025550147"

        let first = Task { await model.call() }
        await fulfillment(of: [entered], timeout: 2)
        let previousPresentation = model.presentationID

        model.prepareForPresentation()
        XCTAssertGreaterThan(model.presentationID, previousPresentation)
        XCTAssertEqual(model.rawNumber, "2025550147")
        XCTAssertTrue(model.isOpening)
        XCTAssertFalse(model.canCall)
        XCTAssertNil(model.notice)
        await model.call()
        XCTAssertEqual(launcher.requests.count, 1)

        launcher.finish()
        await first.value
        XCTAssertEqual(model.notice?.kind, .error)
        XCTAssertFalse(model.isOpening)
        XCTAssertTrue(model.canCall)

        launcher.shouldWait = false
        launcher.failure = nil
        launcher.onOpen = nil
        await model.call()
        XCTAssertEqual(model.notice?.kind, .information)
        XCTAssertEqual(launcher.requests.count, 2)
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
