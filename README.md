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
- For development and packaging: Xcode 15+ with Swift 5.9+.
- For regular calls: iPhone with Calls on Other Devices configured. Confirm it works in a system app before testing CallBar.

## Build and run

~~~sh
git clone https://github.com/Andriikym/callbar.git
cd callbar
swift test
./scripts/build-app.sh
open "dist/$(uname -m)/CallBar.app"
~~~

You can open Package.swift in Xcode. To run the menu bar app, use the built CallBar.app bundle. The script applies a local ad hoc signature; public distribution with Developer ID and notarization is a separate step.

GitHub Actions runs the Swift tests on Apple Silicon, then builds, verifies, and uploads separate Apple Silicon and Intel ZIPs. To build for a specific architecture locally, pass `arm64` or `x86_64` to `./scripts/build-app.sh`. On Linux, only the independent CallBarCore module and its tests are available.

## Try the packaged MVP

The actual UI and a call through iPhone still need hands-on acceptance.

1. Open a successful run of the [CI workflow](https://github.com/Andriikym/callbar/actions/workflows/ci.yml).
2. Download the `CallBar-macOS-arm64` artifact for Apple Silicon or `CallBar-macOS-x86_64` for Intel. GitHub may require you to sign in.
3. Extract the downloaded artifact, then extract the enclosed ZIP.
4. Open CallBar.app and use the phone icon in the menu bar.

The archive contains a development build with an ad hoc signature, not a notarized distribution build. If macOS blocks it, use the source-build instructions above or review the app in System Settings → Privacy & Security. CI artifacts are retained for 14 days; build from source or rerun the workflow after they expire.

## Documentation

- [Implementation plan and future releases](docs/implementation-plan.md)
- [Architecture and technical decisions](docs/architecture.md)
- [Pull request checks and Codex review setup](docs/pull-request-checks.md)
- [Manual testing on a real Mac and iPhone](docs/manual-testing.md)
- [Verified build and current checkpoint](docs/verification.md)

Numbers stay in the current process's memory. The MVP does not store call history, send analytics, or request access to Contacts.
