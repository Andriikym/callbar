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
        XCTAssertFalse(try button("Clear Favorites", in: app.view).isEnabled)
        try button("Add favorite", in: app.view).performClick(nil)
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
        try button("Add favorite", in: app.view).performClick(nil)
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
        try button("Clear Favorites", in: app.view).performClick(nil)
        XCTAssertTrue(labels(in: app.view).contains("Remove 2 saved favorites from Favorites."))
        try button("Cancel", in: app.view).performClick(nil)
        XCTAssertEqual(app.model.lists.favorites.count, 2)
        try button("Clear Favorites", in: app.view).performClick(nil)
        let restore = try blockWrites(to: app.directory.appendingPathComponent("Favorites.json"))
        try button("Clear Favorites", in: app.view).performClick(nil)
        XCTAssertEqual(app.model.lists.favorites.count, 2)
        try restore()
        try button("Retry", in: app.view).performClick(nil)
        XCTAssertTrue(labels(in: app.view).contains("No favorites yet"))
        XCTAssertFalse(try button("Clear Favorites", in: app.view).isEnabled)
        let reopened = SavedCalls(directory: app.directory)
        XCTAssertTrue(reopened.favorites.isEmpty)
        XCTAssertEqual(reopened.history.map(\.id), [attempt.id])
        XCTAssertEqual(app.model.rawNumber, first.number)
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
        XCTAssertEqual(reopened.model.lists.history, app.model.lists.history)
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
        XCTAssertFalse(views(NSButton.self, in: reopened.view).contains { $0.title == "Add favorite" })
        try button("Retry", in: reopened.view).performClick(nil)
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
        try data.write(to: file)
        try button("Retry", in: reopened.view).performClick(nil)
        XCTAssertEqual(reopened.model.lists.favorites.first?.name, "Front desk")
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
            let actionTitle = tab == 1 ? "Edit" : "Remove"
            let action = try button("\(actionTitle) \(favorite.name), \(favorite.number)", in: row)
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
