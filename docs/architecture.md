# CallBar Architecture

## Core decision

CallBar is a local native app for macOS 13+. AppKit manages the menu bar item, renders the popover, and hands phone links to the system. The MVP needs no server or database.

~~~mermaid
flowchart TD
    Delegate[AppDelegate: dependency assembly] --> Status[StatusBarController: NSStatusItem + NSPopover]
    Status --> View[DialerViewController: AppKit]
    View --> Model[DialerViewModel: UI state]
    Model --> UseCase[DialCall: user action]
    UseCase --> Request[CallRequest + PhoneNumber]
    UseCase --> Port[CallLaunching]
    Port --> Adapter[SystemCallLauncher: NSWorkspace]
    Adapter --> OS[Registered tel: handler in macOS]
    OS --> Phone[Configured iPhone calling]
~~~

## Modules

| Module/folder | Responsibility | Dependencies |
| --- | --- | --- |
| Sources/CallBarCore | Validated number, call request, errors, use case, and launch interface | Foundation |
| Sources/CallBar/App | App lifecycle and dependency creation | AppKit, CallBarCore |
| Sources/CallBar/MenuBar | Menu bar icon and popover | AppKit |
| Sources/CallBar/Dialer | Popover state and view, setup guide | AppKit, CallBarCore |
| Sources/CallBar/Platform | System handoff and atomic local storage | AppKit, CallBarCore, Foundation |
| Tests/CallBarCoreTests | Input rules and use case contracts | XCTest, CallBarCore |
| Tests/CallBarTests | View model behavior, errors, and duplicate-call protection | XCTest, CallBar |
| Resources | Bundle metadata and App Sandbox entitlement | — |
| scripts | Create, verify, and package the .app | Bash, Swift CLI, macOS system tools |

One Swift package contains two modules, with dependencies assembled in AppDelegate. A protocol is used only at the operating-system boundary; no dependency container or extra layers are needed.

## Data flow

1. The field keeps the original text in memory only.
2. PhoneNumber removes allowed formatting and validates the result.
3. The view model shows the normalized number and whether calling is available.
4. An explicit button press or Enter validates the input and creates a CallRequest.
5. CallBar records the attempt before starting DialCall.
6. SystemCallLauncher checks for a handler and opens the phone link.
7. The interface reports the observed handoff result and updates the same attempt.

### UI states

- Empty field: neutral hint; calling is unavailable.
- Invalid input: explanation; calling is unavailable.
- Valid input: normalized number; calling is available.
- Handoff in progress: repeat calls and field changes are temporarily disabled.
- Request handed off: informational message; the app cannot know the call outcome.
- Handoff error: message suggesting the user check system calling settings.

UI and call-launch objects run on MainActor. The asynchronous CallLaunching contract makes pending requests testable and allows future improvements to the system adapter without changing the form.

## Number handling rules

- Accept 3–15 ASCII digits with an optional leading plus sign.
- Remove horizontal whitespace, parentheses, a regular hyphen, and common typographic hyphens and dashes.
- Preserve leading zeros and the international plus sign.
- Allow surrounding whitespace and newlines, but reject multiple lines within the input.
- Do not infer a country or replace a local prefix with an international one.
- Reject letters, complete URLs, extensions, control sequences, asterisks, hashes, and ambiguous separators.
- A syntactically valid number does not prove that the number exists or is reachable.

Input is first normalized into the PhoneNumber value type, then used to build a URL. Unvalidated input is never passed directly to NSWorkspace.

## Decisions and rationale

### AppKit

AppKit controls render the form and setup guide. NSStatusItem and NSPopover provide control over opening, focus, Esc, and lifecycle. CallBar creates the popover on demand and releases it on close. The app runs as an accessory without a separate Dock icon.

### System call routing

Use tel: and NSWorkspace. The operating system chooses the handler and manages confirmation. No custom audio stream, microphone access, or contacts are required.

Successfully opening a URL confirms only that the request was handed to a handler. It does not confirm iPhone availability, connection, answer, call duration, or completion. Those states cannot be inferred from the result of NSWorkspace.open.

### Swift Package Manager and bundle script

The project opens in Xcode without a project generator or third-party packages. The script creates a complete .app and signs it ad hoc with the App Sandbox entitlement. CI verifies the bundle and its signed entitlement.

### Storage and privacy

Favorites and Recents use separate files in the packaged app’s sandbox container. CallBar uses Foundation to resolve the container’s Application Support directory and saves changes atomically. If a Recents write fails, the committed file is preserved and Recents shows the latest observed handoff result in the current session with an option to retry saving. Users can remove one attempt or clear the list after confirmation. The Dialer draft stays in memory. Numbers stay out of analytics and diagnostic logs. The app requires no Contacts, microphone, or Accessibility permission and reads the clipboard only when the user pastes.

### Future extensions

In v0.2, CallRequest can add a validated call type. In v0.3, add a separate contacts source. Services gets its own entry point into the same number validation flow. Notifications and reminder storage can be added in v0.5.

## Sources

- [Apple: Phone Links](https://developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference/PhoneLinks/PhoneLinks.html)
- [Apple: FaceTime Links](https://developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference/FacetimeLinks/FacetimeLinks.html)
- [Apple: Make calls on Mac through iPhone](https://support.apple.com/102405)

Apple's archived documentation marks facetime-audio: as iOS-only. Whether it can be launched on the target macOS versions needs a practical check before v0.2.
