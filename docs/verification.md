# MVP Verification

Status: ready for hands-on acceptance; not yet verified with a real iPhone.

## Verified build

- Date: 2026-11-11.
- Source commit: [7e1be5b](https://github.com/Andriikym/callbar/commit/7e1be5b071021d428f6c4b4e8382e311bc0a63bf).
- [Successful macOS CI run](https://github.com/Andriikym/callbar/actions/runs/42997901712).
- [Download CallBar-macOS-universal](https://github.com/Andriikym/callbar/actions/runs/42997901712/artifacts/13844547399).
- Runner: macOS 15.8.2, Apple Silicon.
- Toolchain: Xcode 16.4, Swift 6.1.2.
- Deployment target: macOS 13.0.
- Artifact retention: 14 days, until 2026-11-25 for this run.

## Passed checks

- All 15 XCTest methods passed: 9 for number validation/request handoff and 6 for the view model.
- Release executables compiled for arm64 and x86_64.
- The packaged binary contains both architectures.
- Info.plist is valid and identifies a menu bar app; its development language is English.
- The executable is present and executable in the app bundle.
- The bundle's ad hoc code signature passed strict verification.
- The app archive was uploaded successfully.

## Still pending

- Actual window behavior, focus, keyboard shortcuts, paste, accessibility, and appearance on a user's Mac.
- System confirmation and a completed call through the configured iPhone.
- Runtime checks on Intel and the minimum supported macOS version. Cross-compiling both architectures is not runtime validation on both.
- Developer ID signing and notarization before public distribution.

Use [Mac + iPhone acceptance](manual-testing.md) to record the first two groups of checks. The [implementation plan](implementation-plan.md) keeps these items open.

## Repository state

Work continues from the rewritten initial commit 2a159ce. The English UI and documentation are retained. The new commits add the universal-binary verification fix, align the bundle language with the UI, and record completion of automated verification. Earlier history has not been merged back into main.

## List actions menu · 2026-11-24

The change was based on `origin/main` at `e50b643`. Verification used macOS 27.2.1 on Apple Silicon with Xcode 27.2 and Swift 6.4.2. Both release builds target macOS 13.

| ID | Implementation | Check and observed result |
| --- | --- | --- |
| P1, T5, AC8 | `DialerViewController.loadView`, `showTab`, `showRecents`, and `showFavorites` place one tab-specific button in the shared header. | `testTabActionsMenuContentsAndPlacement` and `testTabsPreserveDraftAndFavoriteEditorUsesCanonicalNumber` passed. [M8.1 and M8.2](manual-testing.md#list-actions-popover-checks--24-november-2026) observed initial Dialer focus, tab visibility, closed menus on entry, and fixed placement as both lists scrolled. |
| P4, AC8 | `ListActionsButton` in `PopoverControls.swift` opens a native menu from the focused button. `DialerViewController` assigns each menu and its accessible label. | `testTabActionsMenuContentsAndPlacement` passed for the role, labels, menu order and separator, and no handoffs. M8.4 observed Return opening and Esc dismissal with focus on the button. M8.5 verified the accessibility tree. Spoken VoiceOver and use from the packaged status item are pending. |
| F1, F5, H4, AC8 | `DialerViewController.addFavorite`, `openEditor`, and `emptyFavorites` reuse the existing editor and expose the empty-state hint. Existing row actions remain in `showFavorites` and `showRecents`. | `testTabsPreserveDraftAndFavoriteEditorUsesCanonicalNumber` and `testListRowsKeepMetadataVisibleAndPinActionsToTrailingEdge` passed. M8.3 observed the hint and menu enablement. |
| F6, Q7, AC5 | `DialerViewController.clearFavorites` and `confirmRemoval` use `SavedCalls.removeFavorites(ids:)` for the entries named by the confirmation. | `testRemovalAndClearUseCancelByDefaultAndStayIndependentOfRecents` passed for default Cancel, failed-write and retry, persistence, and independence from Recents and Dialer. M8.6 observed the list name, count, Esc cancellation, and confirmed clear. |
| H6, Q7, AC5 | `DialerViewController.clearRecents` and `confirmRecentRemoval` collect attempt IDs across date groups and call `SavedCalls.removeAttempts(ids:)`. | `testRecentsRemovalConfirmsByAttemptAndClearPreservesFavoritesAndDraft` passed for a multi-date count, default Cancel, failed-write and retry, persistence, and independence from Favorites and Dialer. M8.6 observed cancellation and confirmed clear across both date groups. |
| P3 | `DialerViewController.showFavorites` and `showRecents` disable mutations when the affected list fails to load and keep the existing recovery action. `SavedCalls.removeAttempts(ids:)` guards against deletion while Recents is unreadable. | `testFailedEditKeepsDraftAndCorruptFavoritesAllowReadOnlyRecovery` and `testRecentsReadRecoveryDisablesClearMenuAction` passed. Corrupt files survived Retry and restoration re-enabled the actions. |
| P6, H6, AC7 | `SavedCalls.removeAttempts(ids:)` removes confirmed IDs from the committed list, staged writes, and session-pending IDs. `finishAttempt` ignores completions whose pending ID was removed. | `testRecentsClearMenuSuppressesPendingResultAndPreservesUnconfirmedAttempts` and `testClearingRecentsDiscardsUnsavedAttemptsAndIgnoresLateCompletion` passed. A late result or retry could not revive a cleared attempt, a newer unconfirmed attempt survived, and a fresh explicit handoff appeared once. M8.7 remains pending as a hands-on check. |

`swift test --parallel` passed all 41 XCTest cases. `./scripts/build-app.sh arm64` and `./scripts/build-app.sh x86_64` produced separate bundles with verified architecture, bundle metadata, and ad hoc signatures before separate packaging edits appeared in the working tree. Runtime popover checks used a native Apple Silicon host and a stub launcher. Real iPhone, Intel runtime, and macOS 13 runtime acceptance remain pending.

The `CallBarUI` scheme passed all four XCUIAutomation cases in one run. `PopoverTestHost.swift` anchors the production controller in a regular test window and gives each case isolated storage and a stub launcher. The test popover stays open across desktop focus changes. The manual check used a transient popover.

| Scenarios | XCTest UI case | Observed result |
| --- | --- | --- |
| M8.1, M8.2, M8.5 · P1, P4, T5, AC8 | `testTabVisibilityMenuContentsAndFixedPlacementWhileScrolling` | **Passed.** Correct initial tab, tab-specific accessible menu button names, closed-by-default menus, separator and action order, popup below its button, fixed header as both lists scroll, and preserved draft. |
| M8.4 · P4, AC8 | `testEscapeClosesEachMenuAndReturnsKeyboardFocusToItsButton` | **Passed.** Esc closed each menu while the popover remained open. Return and Space reopened each menu from the restored focus. |
| M8.3, M8.6 · H6, Q7, AC5, AC8 | `testRecentsClearCountsAllDatesCancelsByDefaultAndPersists` | **Passed.** Arrow and Return selected Clear, default Return canceled, and confirmation covered 14 attempts across two date groups. Clear persisted after relaunch and preserved Favorites and the session draft. Clear was disabled on empty Recents. |
| M8.3, M8.6 · F1, F6, Q7, AC5, AC8 | `testFavoritesClearCancelPersistenceAndEditorFromEmptyMenu` | **Passed.** Esc canceled the 14-favorite confirmation. Confirmed clear preserved both Recents date groups and the session draft, and remained cleared after relaunch. The empty-state menu disabled Clear and opened the blank editor from Add. |
