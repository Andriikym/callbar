# CallBar Implementation Plan

Date: 2026-11-10. Working name: CallBar. Repository: Andriikym/callbar.

Last reviewed: 2026-11-11. The English UI and documentation are retained from the rewritten repository history. Development continues from its new initial commit.

## v0.1 goal

The user opens CallBar from the menu bar, pastes a number that is not in Contacts, and starts a regular call through the configured Mac + iPhone setup.

The first release is limited to four features: menu bar access, manual entry and normal paste, number normalization, and handing a phone call to macOS. Enter, Esc, errors, and brief help support this flow.

## Implementation sequence

### 1. Repository and decisions

- [x] Connect the empty remote repository.
- [x] Add this plan, the architecture, and manual test scenarios.
- [x] Choose Swift 5.9+, macOS 13+, Swift Package Manager, SwiftUI + AppKit.
- [x] Configure macOS CI and a reproducible .app build.

### 2. Independent core

- [x] PhoneNumber: remove allowed formatting while preserving a leading plus sign and zeros.
- [x] Reject ambiguous or unsupported input without silently changing the number.
- [x] CallRequest: build a phone link only from a validated number.
- [x] DialCall + CallLaunching: separate the user flow from the system API.
- [x] Test formatting, edge cases, and request handoff.

### 3. macOS app

- [x] AppDelegate and StatusBarController: icon, popover, dismissal, and app termination.
- [x] SwiftUI popover: field, number preview, errors, call button, Enter, and Esc.
- [x] Automatically focus the field when the popover opens.
- [x] SystemCallLauncher: check for a handler and open tel: through NSWorkspace.
- [x] Clearly report request handoff; never invent a call status.
- [x] Add setup guidance for Mac + iPhone.
- [x] Test view model behavior, including repeat clicks during handoff.

### 4. Verification and packaging

- [x] macOS CI: swift test, release build, create and verify the bundle.
- [x] Save the .app archive as a GitHub Actions artifact.
- [ ] Run the scenarios in manual-testing.md on a real Mac + iPhone.
- [ ] Record macOS/iOS versions and hands-on results.

Completed implementation tasks mean the code is present. Builds and unit tests verify compilation and the tested behavior, but do not replace checks of the UI, Continuity, and system dialogs on real devices. Until those checks are complete, v0.1 is an MVP candidate.

## Current checkpoint

The implementation and automated packaging are complete. All 15 tests pass, and the universal arm64 + x86_64 app has passed bundle and ad hoc signature verification. See the [verification record](verification.md) for the tested commit, CI run, and downloadable artifact.

Next: run the [Mac + iPhone acceptance scenarios](manual-testing.md), record the device versions and results, and fix any confirmed issues before moving to v0.2.

## First hands-on check on Mac

1. Confirm that a regular call through iPhone already works in a system app.
2. Check which handler receives tel: on the selected macOS version and what confirmation it shows.
3. Complete the flow from CallBar and confirm that the call reaches the agreed test number.
4. Separately check facetime: and facetime-audio: for v0.2; do not delay v0.1 for them.

The app uses the registered tel: handler. If the user selected a third-party handler, macOS determines routing. The v0.1 scope does not include automatic iPhone availability diagnostics or call controls.

## After the MVP

| Release | Feature sequence | Completion criterion |
| --- | --- | --- |
| v0.2 | Global shortcut → clipboard action → FaceTime Video → FaceTime Audio after verification | Dial a number from the keyboard and choose a supported call type |
| v0.3 | Favorite numbers → speed dial → system contacts search | Repeat a call without manual entry; denying Contacts access does not break manual entry |
| v0.4 | Country code and international format → call selected text through Services | Supported apps pass selected text; local numbers are not changed without a country choice |
| v0.5 | Temporary contacts → notes → reminders with a Call action | Label a one-time number and return to it from a reminder |

Releases are independent. A global shortcut is different from Enter inside the popover; the MVP implements only Enter. Normal paste into the field does not mean clipboard monitoring.

## Before each release

- Run tests for the changed modules and confirm a successful macOS build.
- Check for accidental calls when opening, pasting, encountering an error, or closing the popover.
- Keep one explicit user action required to start a call.
- Manually check integrations that require macOS or iPhone.

## Current limitations

- The Linux development environment has no AppKit, macOS SDK, or connected iPhone.
- App Store distribution, Developer ID, notarization, and auto-updates need a separate decision.
- Access to system call history, call recording, and custom telephony are outside this plan.
