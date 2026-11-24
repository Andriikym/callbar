# Mac + iPhone Acceptance

Status: pending tests on real devices.

Complete with verified details before calling the MVP ready:

- Commit:
- macOS version:
- Mac architecture (arm64/x86_64):
- iOS version:
- Phone link handler:
- Date and result:

## Setup

1. Build CallBar.app with scripts/build-app.sh or download the macOS CI artifact.
2. Make sure the Mac and iPhone have compatible Apple Account and Calls on Other Devices settings.
3. Test a regular call in a system app. If needed, use [Apple instructions](https://support.apple.com/102405).
4. Use an agreed test number. Do not test calls to emergency services.

## Required scenarios

| Action | Expected result |
| --- | --- |
| Open .app | An icon appears in the menu bar; no separate window or Dock icon appears |
| Click the icon | The form opens and the field is ready for input |
| Close and reopen the form | Focus returns to the field; no call starts automatically |
| Press Esc or click outside | The form closes; the process keeps running |
| Press ⌘V with a valid number | Text is pasted; no call starts automatically |
| Enter a number with parentheses, spaces, and hyphens | The correctly normalized number is shown |
| Enter a local number with a leading zero | The zero is preserved; no country code is added automatically |
| Enter letters, a URL, or multiple lines | An error appears; calling is unavailable |
| Enter a number not in Contacts and press Enter | macOS receives the exact number and shows its standard call flow |
| Confirm the call | The call reaches the test recipient |
| Cancel system confirmation | CallBar does not claim that a conversation took place |
| Disable Calls on Other Devices | macOS handles the connection error; CallBar does not show a false connection status |
| Choose a third-party tel: handler | The request follows macOS settings, as documented |
| Open help and return | The guide is readable and the field is available afterward |
| Open Recents with two attempts to the same number. Select Remove, press Esc, then reopen and confirm | The confirmation shows the number and request time with Cancel as the default. Esc keeps both rows. Confirm removes only the selected attempt |
| Choose Clear Recents… from the Recents ⋯ menu, cancel once, then confirm and relaunch | The confirmation shows the count across dates. Cancel keeps the rows. Confirm clears Recents across restarts and preserves Favorites |
| Check VoiceOver and dark mode | Field and buttons have clear labels; text is readable |
| Choose Quit CallBar | The icon disappears and the process exits |

## List actions popover checks · 24 November 2026

Live checks used macOS 27.2.1 on Apple Silicon, a window-anchored AppKit popover with the production controller, temporary seeded lists, and a stub launcher. The status-item-only fixture timed out when opened through desktop automation.

| Scenario | Action and expected result | Observed result |
| --- | --- | --- |
| **M8.1 · P1, P4, T5, AC8** | Open on Dialer, type a draft, visit both lists, and return to Dialer. Dialer focuses the number field and hides ⋯. Each list starts with its menu closed. The draft stays available and browsing initiates zero calls. | **Passed.** Observed the initial field focus, tab-specific button visibility, closed menus on entry, and the draft after reopening. The stub saw no handoff. |
| **M8.2 · P1, AC8** | With both lists populated, scroll each one and open ⋯. Rows move and the button stays at the upper right above the tabs. Recents shows Clear Recents…. Favorites shows Add Favorite…, a separator, and Clear Favorites…. | **Passed** for fixed placement and action order. Both scroll positions changed and the header stayed in place. |
| **M8.3 · F1, F5, F6, H6, AC8** | With empty Recents, open ⋯ and check disabled Clear Recents…. With empty Favorites, check both hint lines, open ⋯, and verify disabled Clear Favorites… and enabled Add Favorite…. Open the blank editor and cancel it. | **Passed** for both disabled clear actions, the two Favorites hint lines, and enabled Add Favorite…. **Pending** for the manual blank-editor opening and cancellation after the desktop driver lost popover focus. |
| **M8.4 · P4, AC8** | Focus each list’s ⋯ button, open with the keyboard, press Esc, then press Return again. Esc closes only the menu, returns focus to ⋯, and lets Return reopen it. | **Passed.** Return opened both menus and Esc left each popover open with its actions button focused. |
| **M8.5 · P4, AC8** | With VoiceOver, move to ⋯ in each list and listen for “Recents actions” or “Favorites actions” and the menu button role. Open the menu and read the action names and disabled states. | **Passed** for both names, the menu button role, and enabled and disabled menu items in the macOS accessibility tree. **Pending** for spoken VoiceOver behavior. |
| **M8.6 · F6, H6, Q7, AC5** | On fixture data, start a clear for each list and check its name, count, and focused Cancel. Cancel once with Return or Esc, then confirm and relaunch. The other list survives and the current Dialer draft stays intact through clear. | **Passed** for both names, both counts of 14, default Cancel, Recents cancellation by Return, Favorites cancellation by Esc, and both confirmed clears. Recents clear included Today and Yesterday and preserved Favorites. **Pending** for a manual relaunch after both confirms and a manual Favorites clear with populated Recents. |
| **M8.7 · P6, H6, AC7** | Using a delayed stub handoff, confirm Clear Recents while the result is pending. Release the result, retry history storage, then make a fresh stub request. The cleared attempt stays removed and the fresh attempt appears once. | **Pending** as a hands-on check. The AppKit and storage tests exercise this with a controllable stub. |
| **M8.8 · P1, P4, AC8** | Launch the packaged accessory app and open Recents and Favorites from the status item. Verify the same header, native menu placement, and keyboard dismissal. | **Pending.** The tested live popover used a regular AppKit window as its anchor. |

### Repeatable UI tests

Open `CallBarUI.xcodeproj` and test the shared `CallBarUI` scheme, or run this command from the repository in a logged-in macOS graphical session.

```bash
xcodebuild -project CallBarUI.xcodeproj -scheme CallBarUI \
  -destination 'platform=macOS' -parallel-testing-enabled NO test
```

The UI tests drive the production controller through an AppKit popover hosted by a separate test app. The test popover stays open if another app takes focus between test events. Each case creates a fresh temporary storage path and uses a launcher that fails the test host if a call starts. The suite drives the active desktop, where other apps can interrupt its input. The status item, transient dismissal when clicking outside, and spoken VoiceOver remain hands-on checks.

All four UI tests passed on 24 November 2026. They also verified the Favorites separator and menu position, keyboard navigation with the arrow keys, opening and canceling the blank editor from empty Favorites, and persistence across a fresh process for both clears. See the [named results](verification.md#list-actions-menu--2026-11-24).

## What automated tests do not verify

Automated tests cover number normalization, request creation, and the view model with a stub handler. CI confirms macOS compilation and bundle integrity. iPhone availability, system confirmation, and an actual call must be checked manually.
