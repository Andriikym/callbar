# CallBar Architecture

## Core decision

CallBar is a local native app for macOS 13+. SwiftUI renders the popover, while AppKit manages the menu bar item and hands phone links to the system. The MVP needs no server or database.

~~~mermaid
flowchart TD
    Delegate[AppDelegate: dependency assembly] --> Status[StatusBarController: NSStatusItem + NSPopover]
    Status --> View[DialerView: SwiftUI]
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
| Sources/CallBar/MenuBar | Menu bar icon and popover | AppKit, SwiftUI |
| Sources/CallBar/Dialer | Popover state and view, setup guide | SwiftUI, CallBarCore |
| Sources/CallBar/Platform | Handoff to the operating system | AppKit, CallBarCore |
| Tests/CallBarCoreTests | Input rules and use case contracts | XCTest, CallBarCore |
| Tests/CallBarTests | View model behavior, errors, and duplicate-call protection | XCTest, CallBar |
| Resources | Info.plist for the bundle | — |
| scripts | Create, verify, and package the .app | Bash, Swift CLI, macOS system tools |

One Swift package contains two modules, with dependencies assembled in AppDelegate. A protocol is used only at the operating-system boundary; no dependency container or extra layers are needed.

## Data flow

1. The field keeps the original text in memory only.
2. PhoneNumber removes allowed formatting and validates the result.
3. The view model shows the normalized number and whether calling is available.
4. Only an explicit button press or Enter starts DialCall.
5. DialCall validates the input again and creates a CallRequest.
6. SystemCallLauncher checks for a handler and opens the phone link.
7. The interface reports that the request was handed off or shows an error.

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

### SwiftUI + AppKit

SwiftUI simplifies the form and accessibility. NSStatusItem + NSPopover provide explicit control over opening, focus, Esc, and lifecycle. The app runs as an accessory and does not create a separate Dock icon.

### System call routing

Use tel: and NSWorkspace. The operating system chooses the handler and manages confirmation. No custom audio stream, microphone access, or contacts are required.

Successfully opening a URL confirms only that the request was handed to a handler. It does not confirm iPhone availability, connection, answer, call duration, or completion. Those states cannot be inferred from the result of NSWorkspace.open.

### Swift Package Manager and bundle script

The project opens in Xcode without a project generator or third-party packages. The script creates a complete .app with Info.plist, executable, and local ad hoc signature. CI verifies the bundle, not just the executable.

### Storage and privacy

The MVP has no persistent storage, analytics, or number logging. Contacts, microphone, Accessibility, and automatic clipboard reading are not used. Settings and local storage can be added alongside features that need them.

### Future extensions

In v0.2, CallRequest can add a validated call type. In v0.3, add a separate contacts source and local favorites. Services gets its own entry point into the same number validation flow. Notifications and reminder storage can be added in v0.5.

## Sources

- [Apple: Phone Links](https://developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference/PhoneLinks/PhoneLinks.html)
- [Apple: FaceTime Links](https://developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference/FacetimeLinks/FacetimeLinks.html)
- [Apple: Make calls on Mac through iPhone](https://support.apple.com/102405)

Apple's archived documentation marks facetime-audio: as iOS-only. Whether it can be launched on the target macOS versions needs a practical check before v0.2.
