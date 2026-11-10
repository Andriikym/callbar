# CallBar

A native macOS menu bar app: enter or paste a number and hand a regular call to the system calling app through iPhone.

## MVP

- Phone icon in the menu bar and a compact popover.
- Enter a number without adding it to Contacts; paste normally with ⌘V.
- Remove spaces, parentheses, and hyphens while preserving a leading plus sign and zeros.
- Call through iPhone button, Enter to start, and Esc to close.
- Setup instructions for iPhone calls and clear input errors.

CallBar sends the number to the phone link handler registered with macOS. macOS handles the call, confirmation, and connection to iPhone. Successful delivery of a number does not mean the other person answered.

## Requirements

- macOS 13 or later.
- For development and universal builds: Xcode 15+ with Swift 5.9+.
- For regular calls: iPhone with Calls on Other Devices configured. Confirm it works in a system app before testing CallBar.

## Build and run

~~~sh
git clone https://github.com/Andriikym/callbar.git
cd callbar
swift test
./scripts/build-app.sh
open dist/CallBar.app
~~~

You can open Package.swift in Xcode. To run the menu bar app, use the built CallBar.app bundle. The script applies a local ad hoc signature; public distribution with Developer ID and notarization is a separate step.

GitHub Actions checks the project on macOS, builds a universal .app for Apple Silicon and Intel, and saves an archive as a workflow artifact. On Linux, only the independent CallBarCore module and its tests are available.

## Documentation

- [Implementation plan and future releases](docs/implementation-plan.md)
- [Architecture and technical decisions](docs/architecture.md)
- [Manual testing on a real Mac and iPhone](docs/manual-testing.md)

Numbers stay in the current process's memory. The MVP does not store call history, send analytics, or request access to Contacts.
