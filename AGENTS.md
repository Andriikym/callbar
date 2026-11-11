# Working on CallBar

Read [docs/architecture.md](docs/architecture.md) before changing application
behavior. It defines the MVP boundaries and number-handling contract.

## Validation

- Run `swift test --parallel`. Linux runs only CallBarCoreTests; macOS also runs
  CallBarTests, including the system adapter tests with a stub workspace.
- On macOS, run `./scripts/build-app.sh arm64` and `./scripts/build-app.sh x86_64`
  to build and verify both architecture-specific bundles.
- Run `bash -n scripts/build-app.sh scripts/verify-app.sh` when changing scripts.
- Changes to calling, focus, keyboard handling, or the popover still need the
  relevant scenarios in [docs/manual-testing.md](docs/manual-testing.md).
  Do not describe unit tests or a successful URL open as a verified iPhone call.

## Code Review Rules

### Number handling and explicit user intent

- Preserve the number contract in `docs/architecture.md`: 3–15 ASCII digits,
  an optional leading plus, leading zeros, and only the documented formatting.
  Reject URLs, extensions, internal line breaks, invisible controls, and
  ambiguous separators. Never infer a country code or dial unvalidated text.
- Every call must follow an explicit button press or Enter. Editing, pasting,
  opening the popover, and retryable errors must not start calls automatically.
  Keep duplicate submissions disabled throughout an asynchronous handoff and
  restore the UI on both success and failure.

### System boundary and privacy

- Keep CallBarCore independent of AppKit and SwiftUI. Use CallLaunching for
  operating-system handoff and assemble dependencies in AppDelegate; keep UI
  and launch operations on MainActor.
- A successful system URL open means only that the request was handed off.
  Do not infer connection, iPhone availability, answer, or call completion.
- Keep entered numbers in process memory only for the MVP. Flag new number
  logging, analytics, persistence, automatic clipboard reading, or Contacts/
  microphone permissions unless an approved feature changes that requirement.

### Compatibility and evidence

- Preserve macOS 13+, Swift 5.9+, separate arm64 and x86_64 app packages,
  the accessory-app behavior, and bundle/signature verification.
- Request regression coverage when a behavior change can bypass validation,
  send an unintended call, lose duplicate protection, or misreport a handoff.
  Automated adapter tests must use a stub and never open a real phone URL.
- Report actionable defects with the trigger, consequence, and affected code.
  Distinguish confirmed bugs from missing hardware validation; avoid findings
  based only on style or hypothetical future features.
