import CallBarCore
import XCTest
@testable import CallBar

final class StorageV1CompatibilityTests: XCTestCase {
    @MainActor
    func testFreshStoresWriteV1OnFirstCommitAndReopenWithoutRedialing() async throws {
        let directory = try temporaryDirectory()
        let lists = SavedCalls(directory: directory)
        let favorites = directory.appendingPathComponent("Favorites.json")
        let recents = directory.appendingPathComponent("Recents.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: favorites.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: recents.path))

        let favorite = try lists.saveFavorite(id: nil, name: "Desk", rawNumber: "00 123")
        XCTAssertEqual(try records(in: favorites), [["id": favorite.id.uuidString, "name": "Desk", "number": "00123"]])
        XCTAssertFalse(FileManager.default.fileExists(atPath: recents.path))

        let launcher = ControllableLauncher()
        let model = DialerViewModel(dialCall: DialCall(launcher: launcher), lists: lists,
                                    now: { Date(timeIntervalSince1970: 0.1236) })
        model.rawNumber = favorite.number
        await model.call()?.value
        let attempt = try XCTUnwrap(lists.history.first)
        XCTAssertEqual(try records(in: recents), [["id": attempt.id.uuidString, "number": "00123",
                                                   "time": "0.1236", "result": "sent"]])
        let reopened = SavedCalls(directory: directory)
        let reopenedModel = DialerViewModel(dialCall: DialCall(launcher: launcher), lists: reopened)
        reopenedModel.prepareForPresentation()
        reopened.retryHistory()
        XCTAssertEqual(reopened.favorites, [favorite])
        XCTAssertEqual(reopened.history, [attempt])
        XCTAssertEqual(launcher.requests.count, 1)
    }

    @MainActor
    func testFrozenV1FilesSurviveEditsWithStoredResultsAndOrderIntact() throws {
        let directory = try temporaryDirectory()
        let favorites = directory.appendingPathComponent("Favorites.json")
        let recents = directory.appendingPathComponent("Recents.json")
        try FileManager.default.copyItem(at: fixture("Favorites.json"), to: favorites)
        try FileManager.default.copyItem(at: fixture("Recents.json"), to: recents)
        let originalHistory = try Data(contentsOf: recents)
        let originalEntries = try records(in: recents)
        let lists = SavedCalls(directory: directory)
        XCTAssertNil(lists.favoritesReadIssue)
        XCTAssertNil(lists.historyReadIssue)
        XCTAssertEqual(lists.history.map(\.result), [.unknown, .sent, .noHandler, .openFailed, .unknown])
        XCTAssertEqual(lists.history.map { $0.id.uuidString }, originalEntries.compactMap { $0["id"] })
        let desk = try XCTUnwrap(lists.favorite(for: "00123"))
        try lists.saveFavorite(id: desk.id, name: "Renamed desk", rawNumber: desk.number)
        XCTAssertEqual(try Data(contentsOf: recents), originalHistory)

        let attempt = lists.startAttempt(number: "00123", at: Date())
        lists.finishAttempt(attempt, with: .openFailed)
        XCTAssertEqual(Array(try records(in: recents).dropFirst()), originalEntries)
        let reopened = SavedCalls(directory: directory)
        XCTAssertEqual(reopened.favorite(for: "00123")?.id, desk.id)
        XCTAssertEqual(reopened.favorite(for: "00123")?.name, "Renamed desk")
        XCTAssertNotNil(reopened.favorite(for: "+12025550142"))
        XCTAssertEqual(reopened.history, lists.history)
    }

    @MainActor
    func testUnreadableFilesBlockWritesAndRetriesIndependently() async throws {
        let cases: [(String, ListReadIssue)] = [
            (#"{"schemaVersion":2,"entries":{"newLayout":true}}"#, .newerVersion(2)),
            ("[]", .unreadable),
            ("invalid JSON", .unreadable)
        ]
        for (json, expectedIssue) in cases {
            for filename in ["Favorites.json", "Recents.json"] {
                let directory = try temporaryDirectory()
                let blocked = directory.appendingPathComponent(filename)
                let original = Data(json.utf8)
                try original.write(to: blocked)
                let lists = SavedCalls(directory: directory)
                let launcher = ControllableLauncher()
                let model = DialerViewModel(dialCall: DialCall(launcher: launcher), lists: lists)
                model.rawNumber = "00123"
                await model.call()?.value
                if filename == "Favorites.json" {
                    XCTAssertThrowsError(try lists.saveFavorite(id: nil, name: "Desk", rawNumber: "00123"))
                    lists.retryFavoritesRead()
                    XCTAssertEqual(lists.favoritesReadIssue, expectedIssue)
                    XCTAssertEqual(SavedCalls(directory: directory).history.map(\.result), [.sent])
                } else {
                    lists.retryHistory()
                    XCTAssertEqual(lists.historyReadIssue, expectedIssue)
                    let saved = try lists.saveFavorite(id: nil, name: "Desk", rawNumber: "00123")
                    XCTAssertEqual(SavedCalls(directory: directory).favorites, [saved])
                }
                XCTAssertEqual(try Data(contentsOf: blocked), original)
                XCTAssertEqual(launcher.requests.count, 1)
            }
        }
    }

    @MainActor
    func testOneInvalidV1RecordBlocksTheEntireList() throws {
        let directory = try temporaryDirectory()
        for filename in ["Favorites.json", "Recents.json"] {
            let file = directory.appendingPathComponent(filename)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: fixture(filename))) as? [String: Any])
            var entries = try XCTUnwrap(object["entries"] as? [[String: Any]])
            entries[1]["number"] = "00 123"
            let invalid = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "entries": entries])
            try invalid.write(to: file)
            let lists = SavedCalls(directory: directory)
            if filename == "Favorites.json" {
                XCTAssertEqual(lists.favoritesReadIssue, .unreadable)
                XCTAssertTrue(lists.favorites.isEmpty)
                XCTAssertThrowsError(try lists.saveFavorite(id: nil, name: "Desk", rawNumber: "00123"))
            } else {
                XCTAssertEqual(lists.historyReadIssue, .unreadable)
                XCTAssertTrue(lists.history.isEmpty)
                _ = lists.startAttempt(number: "00123", at: Date())
                lists.retryHistory()
            }
            XCTAssertEqual(try Data(contentsOf: file), invalid)
        }
    }

    private func records(in file: URL) throws -> [[String: String]] {
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: file))
        let object = try XCTUnwrap(json as? [String: Any])
        XCTAssertEqual(object["schemaVersion"] as? Int, 1)
        let entries = try XCTUnwrap(object["entries"] as? [[String: Any]])
        return entries.map { $0.mapValues { String(describing: $0) } }
    }

    private func fixture(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/storage-fixtures/v1").appendingPathComponent(name)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        return directory
    }
}
