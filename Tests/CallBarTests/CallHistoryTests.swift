import CallBarCore
import XCTest
@testable import CallBar

final class CallHistoryTests: XCTestCase {
    @MainActor
    func testRetentionAndStorageRetryKeepLatestHundredWithoutRedialing() async throws {
        let directory = temporaryDirectory()
        let lists = SavedCalls(directory: directory)
        let launcher = ControllableLauncher()
        let oldest = try lists.saveFavorite(id: nil, name: "Oldest destination", rawNumber: "0201234567")
        let time = Date(timeIntervalSince1970: 30_000)
        let model = DialerViewModel(dialCall: DialCall(launcher: launcher), lists: lists, now: { time })
        model.rawNumber = oldest.number
        for _ in 1...99 { await model.call()?.value }
        let first = try XCTUnwrap(lists.history.last)
        await model.call()?.value
        XCTAssertEqual(lists.history.count, 100)
        XCTAssertEqual(lists.history.last, first)
        let committed = lists.history

        model.rawNumber = "invalid"
        XCTAssertNil(model.call())
        XCTAssertEqual(lists.history, committed)

        let restore = try blockWrites(to: directory.appendingPathComponent("Recents.json"))
        model.rawNumber = oldest.number
        launcher.failure = .openFailed
        await model.call()?.value
        XCTAssertEqual(launcher.requests.count, 101)
        XCTAssertEqual(model.notice?.kind, .error)
        XCTAssertTrue(lists.historyWriteFailed)
        XCTAssertEqual(lists.history.first?.result, .openFailed)
        XCTAssertEqual(Array(lists.history.dropFirst()), committed)

        try restore()
        lists.retryHistory()
        lists.retryHistory()
        XCTAssertFalse(lists.historyWriteFailed)
        XCTAssertEqual(launcher.requests.count, 101)
        let reopened = SavedCalls(directory: directory)
        XCTAssertEqual(reopened.history.count, 100)
        XCTAssertEqual(Array(reopened.history.dropFirst()), Array(committed.dropLast()))
        XCTAssertEqual(reopened.history.first?.number, oldest.number)
        XCTAssertEqual(reopened.history.first?.time, time)
        XCTAssertEqual(reopened.history.first?.result, .openFailed)
        XCTAssertEqual(Set(reopened.history.map(\.id)).count, 100)
        XCTAssertEqual(reopened.favorites, [oldest])
    }

    @MainActor
    func testStorageFailureAfterHandoffRetainsResultForRetryAndPendingRecoveryIsUnknown() async throws {
        let directory = temporaryDirectory()
        let lists = SavedCalls(directory: directory)
        let launcher = ControllableLauncher()
        launcher.shouldWait = true
        let model = DialerViewModel(dialCall: DialCall(launcher: launcher), lists: lists)
        model.rawNumber = "0201234567"
        let opened = expectation(description: "Request has reached the stub handler")
        launcher.onOpen = { opened.fulfill() }
        let task = try XCTUnwrap(model.call())
        await fulfillment(of: [opened], timeout: 2)
        let pending = try XCTUnwrap(lists.history.first)
        let interrupted = try XCTUnwrap(SavedCalls(directory: directory).history.first)
        XCTAssertEqual(interrupted.id, pending.id)
        XCTAssertEqual(interrupted.time, pending.time)
        XCTAssertEqual(interrupted.result, .unknown)

        let restore = try blockWrites(to: directory.appendingPathComponent("Recents.json"))
        launcher.finish()
        await task.value
        XCTAssertTrue(lists.historyWriteFailed)
        XCTAssertEqual(model.notice?.kind, .information)
        XCTAssertEqual(lists.history.map(\.id), [pending.id])
        XCTAssertEqual(lists.history.map(\.result), [.sent])
        try restore()
        lists.retryHistory()
        lists.retryHistory()
        let history = SavedCalls(directory: directory).history
        XCTAssertEqual(history.map(\.id), [pending.id])
        XCTAssertEqual(history.map(\.result), [.sent])
        XCTAssertEqual(launcher.requests.count, 1)
    }

    @MainActor
    func testClearingRecentsDiscardsUnsavedAttemptsAndIgnoresLateCompletion() async throws {
        let directory = temporaryDirectory()
        let lists = SavedCalls(directory: directory)
        let committed = lists.startAttempt(number: "0201234567", at: Date())
        let restore = try blockWrites(to: directory.appendingPathComponent("Recents.json"))
        let unsaved = lists.startAttempt(number: committed.number, at: Date())
        let ids = Set(lists.history.map(\.id))
        XCTAssertEqual(ids, [committed.id, unsaved.id])
        XCTAssertThrowsError(try lists.removeAttempts(ids: ids))
        XCTAssertEqual(Set(lists.history.map(\.id)), ids)

        try restore()
        try lists.removeAttempts(ids: ids)
        lists.finishAttempt(committed, with: .sent)
        lists.finishAttempt(unsaved, with: .openFailed)
        lists.retryHistory()
        XCTAssertFalse(lists.historyWriteFailed)
        XCTAssertTrue(lists.history.isEmpty)
        XCTAssertTrue(SavedCalls(directory: directory).history.isEmpty)

        let next = lists.startAttempt(number: committed.number, at: Date())
        lists.finishAttempt(next, with: .sent)
        XCTAssertEqual(SavedCalls(directory: directory).history.map(\.id), [next.id])
    }

    private func temporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory
    }
}
