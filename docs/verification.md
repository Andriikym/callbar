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
