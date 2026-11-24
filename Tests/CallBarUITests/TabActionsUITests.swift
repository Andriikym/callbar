import XCTest

final class TabActionsUITests: XCTestCase {
    @MainActor
    func testTabVisibilityMenuContentsAndFixedPlacementWhileScrolling() throws {
        let app = launch()
        defer { app.terminate() }
        let popover = app.popovers.firstMatch
        XCTAssertFalse(popover.menuButtons.firstMatch.exists)
        XCTAssertEqual((popover.radioButtons["Dialer"].value as? NSNumber)?.intValue, 1)
        XCTAssertTrue(popover.radioButtons["Dialer"].frame.minX < popover.radioButtons["Recents"].frame.minX)
        XCTAssertTrue(popover.radioButtons["Recents"].frame.minX < popover.radioButtons["Favorites"].frame.minX)
        popover.textFields["Phone number"].typeText("5550199")

        for (tab, titles) in [("Recents", ["Clear Recents…"]), ("Favorites", ["Add Favorite…", "Clear Favorites…"])] {
            popover.radioButtons[tab].click()
            let actions = popover.menuButtons["\(tab) actions"]
            XCTAssertTrue(actions.waitForExistence(timeout: 3))
            XCTAssertFalse(actions.menus.firstMatch.exists)
            let frame = actions.frame
            let selector = popover.radioButtons["Favorites"].frame
            XCTAssertLessThanOrEqual(frame.maxY, selector.minY)
            XCTAssertEqual(frame.maxX, selector.maxX, accuracy: 6)

            let scroll = popover.scrollViews.firstMatch
            let visibleRow = scroll.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ OR title BEGINSWITH %@", "Sample", "Sample")).firstMatch
            let rowFrame = visibleRow.frame
            scroll.scroll(byDeltaX: 0, deltaY: -275)
            XCTAssertNotEqual(visibleRow.frame, rowFrame)
            XCTAssertEqual(actions.frame, frame)

            actions.click()
            let menu = actions.menus.firstMatch
            XCTAssertTrue(menu.waitForExistence(timeout: 2))
            let items = menu.menuItems.allElementsBoundByIndex
            XCTAssertEqual(items.map(\.title).filter { !$0.isEmpty }, titles, menu.debugDescription)
            XCTAssertEqual(items.count, tab == "Recents" ? 1 : 3)
            XCTAssertGreaterThanOrEqual(try XCTUnwrap(items.first).frame.minY, frame.maxY)
            dismissMenu(menu, in: popover)
        }

        popover.radioButtons["Dialer"].click()
        XCTAssertFalse(popover.menuButtons.firstMatch.exists)
        XCTAssertEqual(popover.textFields["Phone number"].value as? String, "5550199")
    }

    @MainActor
    func testEscapeClosesEachMenuAndReturnsKeyboardFocusToItsButton() throws {
        let app = launch()
        defer { app.terminate() }
        let popover = app.popovers.firstMatch
        for tab in ["Recents", "Favorites"] {
            popover.radioButtons[tab].click()
            let actions = popover.menuButtons["\(tab) actions"]
            let menu = actions.menus.firstMatch
            actions.click()
            XCTAssertTrue(menu.waitForExistence(timeout: 2))
            for key in [XCUIKeyboardKey.return, .space] {
                dismissMenu(menu, in: popover)
                XCTAssertTrue(popover.exists)
                popover.typeKey(key, modifierFlags: [])
                XCTAssertTrue(menu.waitForExistence(timeout: 2), "\(key) should reopen \(tab) actions after Esc")
            }
            dismissMenu(menu, in: popover)
        }
    }

    @MainActor
    func testRecentsClearCountsAllDatesCancelsByDefaultAndPersists() throws {
        let app = launch()
        defer { app.terminate() }
        let popover = app.popovers.firstMatch
        popover.textFields["Phone number"].typeText("5550199")
        popover.radioButtons["Recents"].click()
        XCTAssertTrue(text("Today", in: popover).exists, popover.debugDescription)
        XCTAssertTrue(text("Yesterday", in: popover).exists)
        let actions = popover.menuButtons["Recents actions"]
        choose("Clear Recents…", from: actions, in: popover)
        XCTAssertTrue(text("Remove 14 call attempts from Recents.", in: popover).waitForExistence(timeout: 3))
        popover.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(text("Today", in: popover).exists, popover.debugDescription)
        XCTAssertTrue(text("Yesterday", in: popover).exists)

        choose("Clear Recents…", from: actions, in: popover)
        clearButton("Clear Recents", in: popover).click()
        XCTAssertTrue(text("Calls started from CallBar appear here.", in: popover).exists)
        actions.click()
        let clearItem = menuItem("Clear Recents…", in: actions.menus.firstMatch)
        XCTAssertTrue(clearItem.waitForExistence(timeout: 2))
        XCTAssertFalse(clearItem.isEnabled)
        dismissMenu(actions.menus.firstMatch, in: popover)
        popover.radioButtons["Dialer"].click()
        XCTAssertEqual(popover.textFields["Phone number"].value as? String, "5550199")
        popover.radioButtons["Favorites"].click()
        XCTAssertTrue(sampleRow(in: popover).exists)

        let reopened = relaunch(app)
        reopened.radioButtons["Recents"].click()
        XCTAssertTrue(text("Calls started from CallBar appear here.", in: reopened).waitForExistence(timeout: 3),
                      reopened.debugDescription)
        reopened.radioButtons["Favorites"].click()
        XCTAssertTrue(sampleRow(in: reopened).exists)
    }

    @MainActor
    func testFavoritesClearCancelPersistenceAndEditorFromEmptyMenu() throws {
        let app = launch()
        defer { app.terminate() }
        let popover = app.popovers.firstMatch
        popover.textFields["Phone number"].typeText("5550199")
        popover.radioButtons["Favorites"].click()
        let actions = popover.menuButtons["Favorites actions"]
        choose("Clear Favorites…", from: actions, in: popover)
        XCTAssertTrue(text("Remove 14 saved favorites from Favorites.", in: popover).waitForExistence(timeout: 3))
        popover.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(sampleRow(in: popover).exists)

        choose("Clear Favorites…", from: actions, in: popover)
        clearButton("Clear Favorites", in: popover).click()
        XCTAssertTrue(text("No favorites yet", in: popover).exists)
        XCTAssertTrue(text("Use the ⋯ menu to add a favorite.", in: popover).exists)
        actions.click()
        let menu = actions.menus.firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 2))
        let clearItem = menuItem("Clear Favorites…", in: menu)
        XCTAssertTrue(clearItem.exists)
        XCTAssertFalse(clearItem.isEnabled)
        select("Add Favorite…", in: menu, using: popover)
        let name = popover.textFields["Name"]
        let number = popover.textFields["Phone number"]
        XCTAssertTrue(name.waitForExistence(timeout: 2))
        XCTAssertEqual(name.value as? String ?? "", "")
        XCTAssertEqual(number.value as? String ?? "", "")
        popover.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(text("No favorites yet", in: popover).exists)
        popover.radioButtons["Dialer"].click()
        XCTAssertEqual(popover.textFields["Phone number"].value as? String, "5550199")
        popover.radioButtons["Recents"].click()
        XCTAssertTrue(text("Today", in: popover).exists, popover.debugDescription)
        XCTAssertTrue(text("Yesterday", in: popover).exists)

        let reopened = relaunch(app)
        reopened.radioButtons["Favorites"].click()
        XCTAssertTrue(text("No favorites yet", in: reopened).waitForExistence(timeout: 3), reopened.debugDescription)
        reopened.radioButtons["Recents"].click()
        XCTAssertTrue(text("Today", in: reopened).exists)
        XCTAssertTrue(text("Yesterday", in: reopened).exists)
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let storage = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: storage) }
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["CALLBAR_UI_TEST_STORAGE"] = storage.path
        app.launch()
        XCTAssertTrue(app.popovers.firstMatch.waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func relaunch(_ app: XCUIApplication) -> XCUIElement {
        app.terminate()
        app.launch()
        app.activate()
        let popover = app.popovers.firstMatch
        XCTAssertTrue(popover.waitForExistence(timeout: 5))
        return popover
    }

    @MainActor
    private func choose(_ title: String, from actions: XCUIElement, in popover: XCUIElement) {
        actions.click()
        let menu = actions.menus.firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 3))
        select(title, in: menu, using: popover)
    }

    @MainActor
    private func select(_ title: String, in menu: XCUIElement, using popover: XCUIElement) {
        let enabledItems = menu.menuItems.allElementsBoundByIndex.filter { !$0.title.isEmpty && $0.isEnabled }
        guard let index = enabledItems.firstIndex(where: { $0.title == title }) else {
            XCTFail("Missing enabled menu item \(title)")
            return
        }
        for _ in 0...index { popover.typeKey(.downArrow, modifierFlags: []) }
        popover.typeKey(.return, modifierFlags: [])
    }

    @MainActor
    private func menuItem(_ title: String, in menu: XCUIElement) -> XCUIElement {
        menu.menuItems.matching(NSPredicate(format: "title == %@ OR label == %@", title, title)).firstMatch
    }

    @MainActor
    private func dismissMenu(_ menu: XCUIElement, in popover: XCUIElement) {
        popover.typeKey(.escape, modifierFlags: [])
        let vanished = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == NO"), object: menu)
        wait(for: [vanished], timeout: 2)
    }

    @MainActor
    private func clearButton(_ title: String, in popover: XCUIElement) -> XCUIElement {
        popover.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ OR title BEGINSWITH %@", title, title)).firstMatch
    }

    @MainActor
    private func text(_ value: String, in popover: XCUIElement) -> XCUIElement {
        popover.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ OR title CONTAINS %@ OR value CONTAINS %@", value, value, value)).firstMatch
    }

    @MainActor
    private func sampleRow(in popover: XCUIElement) -> XCUIElement {
        popover.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ OR title BEGINSWITH %@", "Sample 1,", "Sample 1,")).firstMatch
    }
}
