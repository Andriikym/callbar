import AppKit
import CallBarCore
import XCTest
@testable import CallBar

final class FavoritesAcceptanceTests: XCTestCase {
    @MainActor
    func testTabsPreserveDraftAndFavoriteEditorUsesCanonicalNumber() async throws {
        let app = fixture()
        XCTAssertEqual((0..<3).map { app.tabs.label(forSegment: $0) }, ["Dialer", "Recents", "Favorites"])
        XCTAssertEqual(app.tabs.selectedSegment, 0)
        XCTAssertFalse(try button("Save to Favorites", in: app.view).isEnabled)
        let phone = try XCTUnwrap(views(NSTextField.self, in: app.view).first { $0.isEditable })
        phone.stringValue = "(020) 123-4567"
        app.controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: phone))
        let attempt = app.model.lists.startAttempt(number: "0201234567", at: Date())
        app.model.lists.finishAttempt(attempt, with: .sent)

        app.open(2)
        XCTAssertTrue(labels(in: app.view).contains("No favorites yet"))
        XCTAssertTrue(labels(in: app.view).contains("Use the ⋯ menu to add a favorite."))
        XCTAssertFalse(try app.menuItem("Clear Favorites…").isEnabled)
        try app.chooseAction("Add Favorite…")
        let blank = try XCTUnwrap(views(FavoriteEditorView.self, in: app.view).first)
        XCTAssertTrue(blank.nameField.stringValue.isEmpty)
        XCTAssertTrue(blank.numberField.stringValue.isEmpty)
        blank.nameField.stringValue = "Unsaved"
        app.controller.cancelOperation(nil)
        XCTAssertTrue(app.model.lists.favorites.isEmpty)

        app.open(1)
        try button("Save 0201234567 to Favorites", in: app.view).performClick(nil)
        let editor = try XCTUnwrap(views(FavoriteEditorView.self, in: app.view).first)
        XCTAssertEqual(editor.numberField.stringValue, "0201234567")
        editor.nameField.stringValue = " \t "
        try button("Save favorite", in: app.view).performClick(nil)
        XCTAssertTrue(labels(in: app.view).contains("Enter a name."))
        XCTAssertTrue(app.model.lists.favorites.isEmpty)
        editor.nameField.stringValue = "Front desk"
        XCTAssertTrue(editor.control(editor.nameField, textView: NSTextView(), doCommandBy: #selector(NSResponder.insertNewline(_:))))
        XCTAssertEqual(app.model.lists.favorites.map(\.number), ["0201234567"])
        XCTAssertEqual(app.model.lists.history.map(\.id), [attempt.id])
        XCTAssertTrue(try button("Edit Front desk, 0201234567", in: app.view).isEnabled)

        app.open(0)
        XCTAssertEqual(phone.stringValue, "(020) 123-4567")
        try button("Edit Front desk, 0201234567", in: app.view).performClick(nil)
        let existing = try XCTUnwrap(views(FavoriteEditorView.self, in: app.view).first)
        XCTAssertEqual(existing.favorite?.id, app.model.lists.favorites.first?.id)
        app.controller.cancelOperation(nil)

        app.open(2)
        try app.chooseAction("Add Favorite…")
        let duplicate = try XCTUnwrap(views(FavoriteEditorView.self, in: app.view).first)
        duplicate.nameField.stringValue = "Reception"
        duplicate.numberField.stringValue = "020 123 4567"
        try button("Save favorite", in: app.view).performClick(nil)
        try button("Edit existing favorite", in: app.view).performClick(nil)
        XCTAssertEqual(views(FavoriteEditorView.self, in: app.view).first?.nameField.stringValue, "Front desk")
        XCTAssertEqual(SavedCalls(directory: app.directory).favorites.map(\.number), ["0201234567"])
        XCTAssertTrue(app.launcher.requests.isEmpty)
    }

    @MainActor
    func testSelectEditAndCallKeepHistoricalDestination() async throws {
        let app = fixture()
        let frontDesk = try app.model.lists.saveFavorite(id: nil, name: "Front desk", rawNumber: "0201234567")
        let other = try app.model.lists.saveFavorite(id: nil, name: "Front desk", rawNumber: "+44201234567")
        XCTAssertEqual(app.model.lists.favorites.map(\.number), [other.number, frontDesk.number])
        let attempt = app.model.lists.startAttempt(number: frontDesk.number, at: Date())
        app.model.lists.finishAttempt(attempt, with: .sent)

        app.open(2)
        try button("Front desk, \(frontDesk.number)", in: app.view).performClick(nil)
        XCTAssertEqual(app.model.rawNumber, frontDesk.number)
        XCTAssertEqual(app.tabs.selectedSegment, 0)

        app.open(2)
        try button("Edit Front desk, \(frontDesk.number)", in: app.view).performClick(nil)
        let editor = try XCTUnwrap(views(FavoriteEditorView.self, in: app.view).first)
        editor.nameField.stringValue = "Alex"
        editor.numberField.stringValue = "+44 20 123 4567"
        try button("Save favorite", in: app.view).performClick(nil)
        XCTAssertTrue(labels(in: app.view).contains("This number is already saved as Front desk."))
        XCTAssertEqual(app.model.lists.favorite(for: frontDesk.number), frontDesk)
        editor.numberField.stringValue = "(020) 123-4567"
        try button("Save favorite", in: app.view).performClick(nil)
        XCTAssertEqual(app.model.lists.favorites.first?.id, frontDesk.id)

        app.open(1)
        XCTAssertEqual(views(NumberRowButton.self, in: app.view).first?.titleLabel.stringValue, "Alex")
        try button("Edit Alex, \(frontDesk.number)", in: app.view).performClick(nil)
        let change = try XCTUnwrap(views(FavoriteEditorView.self, in: app.view).first)
        change.numberField.stringValue = "0201234568"
        try button("Save favorite", in: app.view).performClick(nil)
        let historical = try XCTUnwrap(views(NumberRowButton.self, in: app.view).first)
        XCTAssertEqual(historical.titleLabel.stringValue, frontDesk.number)
        XCTAssertEqual(app.model.rawNumber, frontDesk.number)
        let enter = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                                   windowNumber: 0, context: nil, characters: "\r", charactersIgnoringModifiers: "\r",
                                                   isARepeat: false, keyCode: 36))
        historical.keyDown(with: enter)
        XCTAssertEqual(app.tabs.selectedSegment, 0)
        XCTAssertEqual(app.model.rawNumber, frontDesk.number)
        XCTAssertEqual(app.model.lists.history.map(\.id), [attempt.id])
        XCTAssertTrue(app.launcher.requests.isEmpty)

        let updated = try XCTUnwrap(views(NSTextField.self, in: app.view).first { $0.isEditable })
        updated.stringValue = "0201234569"
        let opened = expectation(description: "Calling app opened once")
        app.launcher.onOpen = { opened.fulfill() }
        try button("Call through iPhone", in: app.view).performClick(nil)
        await fulfillment(of: [opened], timeout: 2)
        XCTAssertEqual(app.launcher.requests.map(\.number.canonical), ["0201234569"])
        XCTAssertEqual(app.model.lists.history.map(\.number), ["0201234569", frontDesk.number])
        XCTAssertEqual(SavedCalls(directory: app.directory).favorite(for: "0201234568")?.name, "Alex")
    }

    @MainActor
    func testRemovalAndClearUseCancelByDefaultAndStayIndependentOfRecents() async throws {
        let app = fixture()
        let first = try app.model.lists.saveFavorite(id: nil, name: "Alex", rawNumber: "0201234567")
        let second = try app.model.lists.saveFavorite(id: nil, name: "Alex", rawNumber: "0201234568")
        let attempt = app.model.lists.startAttempt(number: first.number, at: Date())
        app.model.lists.finishAttempt(attempt, with: .sent)
        app.open(2)
        try button("Alex, \(first.number)", in: app.view).performClick(nil)
        app.open(2)
        try button("Remove Alex, \(first.number)", in: app.view).performClick(nil)
        XCTAssertTrue(labels(in: app.view).contains("Alex\n\(first.number)"))
        XCTAssertEqual(try button("Cancel", in: app.view).keyEquivalent, "\r")
        app.controller.cancelOperation(nil)
        XCTAssertEqual(app.model.lists.favorites.count, 2)
        try button("Remove Alex, \(first.number)", in: app.view).performClick(nil)
        let confirmed = try button("Remove", in: app.view)
        let restoreRemoval = try blockWrites(to: app.directory.appendingPathComponent("Favorites.json"))
        confirmed.performClick(nil)
        XCTAssertEqual(app.model.lists.favorites.count, 2)
        try restoreRemoval()
        try button("Retry", in: app.view).performClick(nil)
        confirmed.performClick(nil)
        XCTAssertEqual(app.model.lists.favorites, [second])
        XCTAssertEqual(SavedCalls(directory: app.directory).favorites, [second])
        app.open(1)
        XCTAssertTrue(try button("Save \(first.number) to Favorites", in: app.view).isEnabled)
        app.open(0)
        XCTAssertEqual(app.model.rawNumber, first.number)

        _ = try app.model.lists.saveFavorite(id: nil, name: "Same building", rawNumber: "0201234560")
        app.open(2)
        try app.chooseAction("Clear Favorites…")
        XCTAssertTrue(labels(in: app.view).contains("Clear Favorites?"))
        XCTAssertTrue(labels(in: app.view).contains("Remove 2 saved favorites from Favorites."))
        XCTAssertEqual(try button("Cancel", in: app.view).keyEquivalent, "\r")
        try button("Cancel", in: app.view).performClick(nil)
        XCTAssertEqual(app.model.lists.favorites.count, 2)
        try app.chooseAction("Clear Favorites…")
        let restore = try blockWrites(to: app.directory.appendingPathComponent("Favorites.json"))
        try button("Clear Favorites", in: app.view).performClick(nil)
        XCTAssertEqual(app.model.lists.favorites.count, 2)
        try restore()
        XCTAssertEqual(SavedCalls(directory: app.directory).favorites, app.model.lists.favorites)
        try button("Retry", in: app.view).performClick(nil)
        XCTAssertTrue(labels(in: app.view).contains("No favorites yet"))
        XCTAssertFalse(try app.menuItem("Clear Favorites…").isEnabled)
        XCTAssertTrue(try app.menuItem("Add Favorite…").isEnabled)
        let reopened = SavedCalls(directory: app.directory)
        XCTAssertTrue(reopened.favorites.isEmpty)
        XCTAssertEqual(reopened.history.map(\.id), [attempt.id])
        XCTAssertEqual(app.model.rawNumber, first.number)

        let last = try app.model.lists.saveFavorite(id: nil, name: "Last favorite", rawNumber: first.number)
        app.open(2)
        try button("Remove \(last.name), \(last.number)", in: app.view).performClick(nil)
        try button("Remove", in: app.view).performClick(nil)
        XCTAssertTrue(labels(in: app.view).contains("Use the ⋯ menu to add a favorite."))
        XCTAssertTrue(try app.menuItem("Add Favorite…").isEnabled)
        XCTAssertFalse(try app.menuItem("Clear Favorites…").isEnabled)
        XCTAssertTrue(app.launcher.requests.isEmpty)
    }

    @MainActor
    func testDialerEnterRecordsOnlyTheExplicitValidCallAndRestoresItsFailure() async throws {
        let app = fixture()
        let first = try app.model.lists.saveFavorite(id: nil, name: "Alex", rawNumber: "0201234567")
        let field = try XCTUnwrap(views(NSTextField.self, in: app.view).first { $0.isEditable })
        let enter = #selector(NSResponder.insertNewline(_:))
        let fieldEditor = NSTextView()
        XCTAssertTrue(app.controller.control(field, textView: fieldEditor, doCommandBy: enter))
        field.stringValue = "invalid"
        XCTAssertTrue(app.controller.control(field, textView: fieldEditor, doCommandBy: enter))
        XCTAssertTrue(app.model.lists.history.isEmpty)
        XCTAssertTrue(app.launcher.requests.isEmpty)

        app.open(2)
        try button("Alex, \(first.number)", in: app.view).performClick(nil)
        XCTAssertTrue(app.model.lists.history.isEmpty)
        let opened = expectation(description: "Calling app handoff attempted once")
        app.launcher.failure = .noHandler
        app.launcher.onOpen = { opened.fulfill() }
        XCTAssertTrue(app.controller.control(field, textView: fieldEditor, doCommandBy: enter))
        await fulfillment(of: [opened], timeout: 2)
        XCTAssertEqual(app.launcher.requests.map(\.number.canonical), [first.number])
        XCTAssertEqual(app.model.rawNumber, first.number)
        XCTAssertTrue(labels(in: app.view).contains { $0.contains("could not find a calling app") })
        let reopened = fixture(directory: app.directory)
        let savedHistory = reopened.model.lists.history
        let currentHistory = app.model.lists.history
        XCTAssertEqual(savedHistory.map(\.id), currentHistory.map(\.id))
        XCTAssertEqual(savedHistory.map(\.number), currentHistory.map(\.number))
        XCTAssertEqual(savedHistory.map(\.result), currentHistory.map(\.result))
        for (saved, current) in zip(savedHistory, currentHistory) {
            XCTAssertEqual(saved.time.timeIntervalSince1970, current.time.timeIntervalSince1970, accuracy: 0.000_001)
        }
        XCTAssertEqual(reopened.model.lists.history.map(\.result), [.noHandler])
        XCTAssertEqual(reopened.model.lists.favorites, [first])
        XCTAssertTrue(reopened.model.rawNumber.isEmpty)
        XCTAssertTrue(reopened.launcher.requests.isEmpty)
    }

    @MainActor
    func testFailedEditKeepsDraftAndCorruptFavoritesAllowReadOnlyRecovery() async throws {
        let app = fixture()
        let original = try app.model.lists.saveFavorite(id: nil, name: "Alex", rawNumber: "0201234567")
        let file = app.directory.appendingPathComponent("Favorites.json")
        let restore = try blockWrites(to: file)
        app.open(2)
        try button("Edit Alex, \(original.number)", in: app.view).performClick(nil)
        let editor = try XCTUnwrap(views(FavoriteEditorView.self, in: app.view).first)
        editor.nameField.stringValue = "Front desk"
        try button("Save favorite", in: app.view).performClick(nil)
        XCTAssertEqual(app.model.lists.favorites, [original])
        XCTAssertEqual(editor.nameField.stringValue, "Front desk")
        try restore()
        try button("Retry save", in: app.view).performClick(nil)
        XCTAssertEqual(SavedCalls(directory: app.directory).favorites.first?.name, "Front desk")

        let data = try Data(contentsOf: file)
        let corrupt = Data("invalid JSON".utf8)
        try corrupt.write(to: file)
        let reopened = fixture(directory: app.directory)
        reopened.open(2)
        XCTAssertTrue(reopened.model.lists.favoritesReadFailed)
        XCTAssertFalse(labels(in: reopened.view).contains("No favorites yet"))
        XCTAssertFalse(try reopened.menuItem("Add Favorite…").isEnabled)
        XCTAssertFalse(try reopened.menuItem("Clear Favorites…").isEnabled)
        try button("Retry", in: reopened.view).performClick(nil)
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
        try data.write(to: file)
        try button("Retry", in: reopened.view).performClick(nil)
        XCTAssertEqual(reopened.model.lists.favorites.first?.name, "Front desk")
        XCTAssertTrue(try reopened.menuItem("Add Favorite…").isEnabled)
        XCTAssertTrue(try reopened.menuItem("Clear Favorites…").isEnabled)
    }

    @MainActor
    func testRecentsRemovalConfirmsByAttemptAndClearPreservesFavoritesAndDraft() async throws {
        let app = fixture()
        let lists = app.model.lists
        let favorite = try lists.saveFavorite(id: nil, name: "Front desk", rawNumber: "0201234567")
        let phone = try XCTUnwrap(views(NSTextField.self, in: app.view).first { $0.isEditable })
        phone.stringValue = "5551234"
        let time = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        let first = lists.startAttempt(number: favorite.number, at: time)
        lists.finishAttempt(first, with: .sent)
        let second = lists.startAttempt(number: favorite.number, at: time)
        lists.finishAttempt(second, with: .openFailed)
        app.open(1)

        let label = "Remove call to \(favorite.number), \(time.formatted())"
        try button(label, in: app.view).performClick(nil)
        XCTAssertTrue(labels(in: app.view).contains("Remove call attempt?"))
        XCTAssertEqual(try button("Cancel", in: app.view).keyEquivalent, "\r")
        app.controller.cancelOperation(nil)
        XCTAssertEqual(lists.history.map(\.id), [second.id, first.id])

        let restore = try blockWrites(to: app.directory.appendingPathComponent("Recents.json"))
        try button(label, in: app.view).performClick(nil)
        try button("Remove", in: app.view).performClick(nil)
        XCTAssertEqual(lists.history.map(\.id), [second.id, first.id])
        try restore()
        try button("Retry", in: app.view).performClick(nil)
        XCTAssertEqual(SavedCalls(directory: app.directory).history.map(\.id), [first.id])

        let newer = lists.startAttempt(number: "5554321", at: Date())
        lists.finishAttempt(newer, with: .noHandler)
        app.open(1)
        XCTAssertTrue(labels(in: app.view).contains("Today"))
        XCTAssertTrue(labels(in: app.view).contains("Yesterday"))
        try app.chooseAction("Clear Recents…")
        XCTAssertTrue(labels(in: app.view).contains("Clear Recents?"))
        XCTAssertTrue(labels(in: app.view).contains("Remove 2 call attempts from Recents."))
        XCTAssertEqual(try button("Cancel", in: app.view).keyEquivalent, "\r")
        app.controller.cancelOperation(nil)
        XCTAssertEqual(lists.history.map(\.id), [newer.id, first.id])

        try app.chooseAction("Clear Recents…")
        let restoreClear = try blockWrites(to: app.directory.appendingPathComponent("Recents.json"))
        try button("Clear Recents", in: app.view).performClick(nil)
        XCTAssertEqual(lists.history.map(\.id), [newer.id, first.id])
        try restoreClear()
        let savedHistory = SavedCalls(directory: app.directory).history
        XCTAssertEqual(savedHistory.map(\.id), lists.history.map(\.id))
        XCTAssertEqual(savedHistory.map(\.number), lists.history.map(\.number))
        XCTAssertEqual(savedHistory.map(\.result), lists.history.map(\.result))
        for (saved, current) in zip(savedHistory, lists.history) {
            XCTAssertEqual(saved.time.timeIntervalSince1970, current.time.timeIntervalSince1970, accuracy: 0.000_001)
        }
        try button("Retry", in: app.view).performClick(nil)
        XCTAssertFalse(try app.menuItem("Clear Recents…").isEnabled)
        let reopened = SavedCalls(directory: app.directory)
        XCTAssertTrue(reopened.history.isEmpty)
        XCTAssertEqual(reopened.favorites, [favorite])
        XCTAssertEqual(app.model.rawNumber, "5551234")
        XCTAssertTrue(app.launcher.requests.isEmpty)
    }

    @MainActor
    func testTabActionsMenuContentsAndPlacement() async throws {
        let app = fixture()
        XCTAssertTrue(views(ListActionsButton.self, in: app.view).isEmpty)
        for (tab, label) in [(1, "Recents actions"), (2, "Favorites actions")] {
            app.open(tab)
            let actions = try XCTUnwrap(views(ListActionsButton.self, in: app.view).first)
            XCTAssertEqual(actions.accessibilityLabel(), label)
            XCTAssertEqual(actions.accessibilityRole(), .menuButton)
            XCTAssertTrue(actions.isEnabled)
            let menu = try XCTUnwrap(actions.menu)
            XCTAssertEqual(menu.items.map { $0.isSeparatorItem ? "separator" : $0.title },
                           tab == 1 ? ["Clear Recents…"] : ["Add Favorite…", "separator", "Clear Favorites…"])
            XCTAssertFalse(try app.menuItem(tab == 1 ? "Clear Recents…" : "Clear Favorites…").isEnabled)
            if tab == 2 { XCTAssertTrue(try app.menuItem("Add Favorite…").isEnabled) }
            XCTAssertFalse(views(NSButton.self, in: app.view).contains {
                ["Clear Recents", "Clear Favorites", "Add favorite"].contains($0.title)
            })
        }
        let earlier = Date(timeIntervalSinceNow: -86_400)
        for index in 0..<12 {
            let number = "55501\(String(format: "%02d", index))"
            _ = try app.model.lists.saveFavorite(id: nil, name: "Test \(index)", rawNumber: number)
            let attempt = app.model.lists.startAttempt(number: number, at: index < 6 ? earlier : Date())
            app.model.lists.finishAttempt(attempt, with: .sent)
        }
        for tab in [1, 2] {
            app.open(tab)
            app.view.layoutSubtreeIfNeeded()
            let actions = try XCTUnwrap(views(ListActionsButton.self, in: app.view).first)
            let scroll = try XCTUnwrap(views(NSScrollView.self, in: app.view).first)
            let frame = actions.convert(actions.bounds, to: app.view)
            let tabFrame = app.tabs.convert(app.tabs.bounds, to: app.view)
            XCTAssertGreaterThanOrEqual(frame.minY, tabFrame.maxY)
            // Native control bounds can vary slightly across AppKit versions.
            XCTAssertEqual(frame.maxX, tabFrame.maxX, accuracy: 6)
            XCTAssertFalse(actions.isDescendant(of: scroll))
            XCTAssertLessThan(tabFrame.minY - scroll.convert(scroll.bounds, to: app.view).maxY, 16)
            scroll.contentView.scroll(to: NSPoint(x: 0, y: 100))
            scroll.reflectScrolledClipView(scroll.contentView)
            XCTAssertGreaterThan(scroll.contentView.bounds.minY, 0)
            XCTAssertEqual(actions.convert(actions.bounds, to: app.view), frame)
        }
        app.open(0)
        XCTAssertTrue(views(ListActionsButton.self, in: app.view).isEmpty)
        XCTAssertTrue(app.launcher.requests.isEmpty)
    }

    @MainActor
    func testRecentsClearMenuSuppressesPendingResultAndPreservesUnconfirmedAttempts() async throws {
        let app = fixture()
        app.launcher.shouldWait = true
        let opened = expectation(description: "Pending handoff reached the stub")
        app.launcher.onOpen = { opened.fulfill() }
        app.model.rawNumber = "5550100"
        let task = try XCTUnwrap(app.model.call())
        await fulfillment(of: [opened], timeout: 2)
        defer { app.launcher.finish() }
        app.open(1)
        try app.chooseAction("Clear Recents…")
        XCTAssertTrue(labels(in: app.view).contains("Remove 1 call attempt from Recents."))

        let unconfirmed = app.model.lists.startAttempt(number: "5550101", at: Date())
        app.model.lists.finishAttempt(unconfirmed, with: .openFailed)
        try button("Clear Recents", in: app.view).performClick(nil)
        app.launcher.finish()
        await task.value
        app.model.lists.retryHistory()
        XCTAssertEqual(SavedCalls(directory: app.directory).history.map(\.id), [unconfirmed.id])
        XCTAssertEqual(app.model.lists.history.map(\.id), [unconfirmed.id])
        XCTAssertEqual(app.launcher.requests.count, 1)

        app.launcher.shouldWait = false
        app.launcher.onOpen = nil
        app.model.rawNumber = "5550102"
        await app.model.call()?.value
        XCTAssertEqual(SavedCalls(directory: app.directory).history.map(\.number), ["5550102", "5550101"])
        XCTAssertEqual(app.launcher.requests.map(\.number.canonical), ["5550100", "5550102"])
    }

    @MainActor
    func testRecentsReadRecoveryDisablesClearMenuAction() async throws {
        let app = fixture()
        let attempt = app.model.lists.startAttempt(number: "5550100", at: Date())
        app.model.lists.finishAttempt(attempt, with: .sent)
        let file = app.directory.appendingPathComponent("Recents.json")
        let contents = try Data(contentsOf: file)
        let corrupt = Data("invalid JSON".utf8)
        try corrupt.write(to: file)
        let reopened = fixture(directory: app.directory)
        reopened.open(1)
        XCTAssertFalse(try reopened.menuItem("Clear Recents…").isEnabled)
        XCTAssertFalse(labels(in: reopened.view).contains("Calls started from CallBar appear here."))
        try button("Retry", in: reopened.view).performClick(nil)
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
        XCTAssertTrue(reopened.model.lists.historyReadFailed)
        try contents.write(to: file)
        try button("Retry", in: reopened.view).performClick(nil)
        XCTAssertTrue(try reopened.menuItem("Clear Recents…").isEnabled)
        XCTAssertEqual(reopened.model.lists.history.map(\.id), [attempt.id])
        XCTAssertTrue(reopened.launcher.requests.isEmpty)
    }

    @MainActor
    func testListRowsKeepMetadataVisibleAndPinActionsToTrailingEdge() async throws {
        let app = fixture()
        let favorite = try app.model.lists.saveFavorite(
            id: nil, name: "Front desk with a name long enough to truncate at the edge of the popover", rawNumber: "+12025550147"
        )
        let time = Date()
        let attempt = app.model.lists.startAttempt(number: favorite.number, at: time)
        app.model.lists.finishAttempt(attempt, with: .sent)

        for tab in [1, 2] {
            app.open(tab)
            app.view.layoutSubtreeIfNeeded()
            let selection = try XCTUnwrap(views(NumberRowButton.self, in: app.view).first)
            let row = try XCTUnwrap(selection.superview)
            let actionTitle = tab == 1 ? "Remove call to \(favorite.number), \(time.formatted())"
                : "Remove \(favorite.name), \(favorite.number)"
            let action = try button(actionTitle, in: row)
            let titleFrame = selection.titleLabel.convert(selection.titleLabel.bounds, to: row)
            let detailFrame = selection.detailLabel.convert(selection.detailLabel.bounds, to: row)
            let actionFrame = action.convert(action.bounds, to: row)
            XCTAssertGreaterThan(row.bounds.width, 320)
            XCTAssertEqual(actionFrame.maxX, row.bounds.maxX, accuracy: 1)
            XCTAssertGreaterThanOrEqual(detailFrame.width, selection.detailLabel.intrinsicContentSize.width)
            XCTAssertGreaterThan(titleFrame.minY, detailFrame.minY)
            XCTAssertEqual(titleFrame.minX, detailFrame.minX, accuracy: 1)
            XCTAssertEqual(selection.detailLabel.stringValue,
                           tab == 1 ? "\(favorite.number) · \(time.formatted(date: .omitted, time: .shortened))" : favorite.number)
        }
    }

    @MainActor
    private func fixture(directory: URL? = nil) -> Fixture {
        _ = NSApplication.shared
        let directory = directory ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let launcher = ControllableLauncher()
        let model = DialerViewModel(dialCall: DialCall(launcher: launcher), lists: SavedCalls(directory: directory))
        let controller = DialerViewController(model: model, onClose: {})
        let view = controller.view
        let tabs = views(NSSegmentedControl.self, in: view)[0]
        return Fixture(directory: directory, launcher: launcher, model: model, controller: controller, view: view, tabs: tabs)
    }

    @MainActor
    private func views<T: NSView>(_ type: T.Type, in view: NSView) -> [T] {
        guard !view.isHidden else { return [] }
        return (view as? T).map { [$0] } ?? view.subviews.flatMap { views(type, in: $0) }
    }

    @MainActor
    private func button(_ title: String, in view: NSView) throws -> NSButton {
        try XCTUnwrap(views(NSButton.self, in: view).first { $0.title == title || $0.accessibilityLabel() == title }, title)
    }

    @MainActor
    private func labels(in view: NSView) -> [String] {
        views(NSTextField.self, in: view).filter { !$0.isEditable }.map(\.stringValue)
    }
}

@MainActor
private struct Fixture {
    let directory: URL
    let launcher: ControllableLauncher
    let model: DialerViewModel
    let controller: DialerViewController
    let view: NSView
    let tabs: NSSegmentedControl

    func open(_ index: Int) {
        tabs.selectedSegment = index
        tabs.sendAction(tabs.action, to: tabs.target)
    }

    func menuItem(_ title: String) throws -> NSMenuItem {
        let chrome = try XCTUnwrap(tabs.superview as? NSStackView)
        let header = try XCTUnwrap(chrome.arrangedSubviews.first as? NSStackView)
        let actions = try XCTUnwrap(header.arrangedSubviews.compactMap { $0 as? ListActionsButton }.first)
        return try XCTUnwrap(actions.menu?.item(withTitle: title), title)
    }

    func chooseAction(_ title: String) throws {
        let item = try menuItem(title)
        XCTAssertTrue(item.isEnabled)
        let menu = try XCTUnwrap(item.menu)
        menu.performActionForItem(at: menu.index(of: item))
    }
}

func blockWrites(to file: URL) throws -> () throws -> Void {
    let manager = FileManager.default
    let backup = file.appendingPathExtension("backup")
    try manager.moveItem(at: file, to: backup)
    try manager.createDirectory(at: file, withIntermediateDirectories: false)
    return {
        try manager.removeItem(at: file)
        try manager.moveItem(at: backup, to: file)
    }
}
