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
| Check VoiceOver and dark mode | Field and buttons have clear labels; text is readable |
| Choose Quit CallBar | The icon disappears and the process exits |

## What automated tests do not verify

Automated tests cover number normalization, request creation, and the view model with a stub handler. CI confirms macOS compilation and bundle integrity. iPhone availability, system confirmation, and an actual call must be checked manually.
