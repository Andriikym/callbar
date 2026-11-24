# Favorites and Recents on disk

Version 1 starts with an empty storage directory on a fresh install. A pre-v1 development build may have written a bare JSON array. Opening that file shows the affected list's recovery message and preserves its contents. Version 1 is the baseline for future upgrades.

## V1 file format

`Favorites.json` and `Recents.json` each contain a UTF-8 JSON object with two required fields. `schemaVersion` is the integer `1`. `entries` is an array, and an empty array represents a saved, empty list. Each file has its own version number, independent of the app release. The examples use synthetic records. [Favorites fixture](storage-fixtures/v1/Favorites.json) · [Recents fixture](storage-fixtures/v1/Recents.json)

| Entry field | Favorites | Recents |
| --- | --- | --- |
| `id` | UUID string identifying the favorite across edits. | UUID string identifying one attempt. Repeated attempts to the same number have distinct IDs. |
| `number` | Canonical phone number as a JSON string. Each number appears at most once. | Canonical phone number as a JSON string, captured when the user initiates the attempt. |
| `name` | Required display name, trimmed and nonempty. | |
| `time` | | Required UTC timestamp of the explicit call action, rounded to the nearest millisecond. Example: `2026-11-01T12:00:00.125Z`. |
| `result` | | Required string. Allowed values are `pending`, `sent`, `noHandler`, `openFailed`, and `unknown`. |

Both lists preserve an optional leading plus and all 3–15 ASCII digits, including leading zeros. IDs are unique within a list. Favorites sort by name for display. Recents stores up to 100 attempts in newest-first activation order. Array order settles ties when timestamps match. A stored `pending` from an earlier session displays as “Result unknown.” A stored `sent` records only a successful system handoff. [Number rules](architecture.md#number-handling-rules) · [Product decisions Q1–Q8](requirements.md)

## Compatibility rules

1. Swift uses the stored property names on `Favorite` and `CallAttempt` as JSON keys. Those names, the result strings, and the UTC timestamp format are part of the v1 contract.
2. On open, identify the file version before decoding entries. A missing file starts an empty list. An unreadable file, a pre-v1 array, or an invalid v1 record puts that list in its existing recovery state and blocks writes to it. A newer version also blocks writes and tells the user which list needs a newer CallBar. Opening the other file proceeds independently.
3. Write the current version atomically on each commit. Bump the affected file's version when the meaning changes or an older writer could discard data. For example, adding a saved note to Favorites needs a version bump if the v1 writer would drop it when renaming a favorite.
4. Introduce the first upgrade when a real v2 format is defined. Decode the complete v1 file, convert in memory, validate every target record, then atomically replace that file. On failure, preserve the original bytes and allow retry. Opening an already current file requires no rewrite. Keep conversions within storage so a retry can never replay a call.

## Upgrade test plan

Copy the fixtures into a fresh temporary directory for each test. Freeze the examples when v1 ships so future releases are checked against the actual earlier representation. Use the production storage entry points and a stub launcher for checks involving the dialer.

| When | Scenario | Acceptance check |
| --- | --- | --- |
| v1 | Open with both files missing, save the first favorite, and record one attempt through the stub. | Each file is created at version 1 on its own first commit. Reopening preserves both records and causes zero additional handoffs. |
| v1 | Open both fixtures. Rename one favorite, then reopen both lists. | IDs and numbers survive exactly, including `00123` and the leading plus. Recents retains all five result values on disk and the activation order of the tied attempts. The interrupted attempt displays as unknown. |
| v1 | Give one file version 2. Try an edit or history save, then retry. Repeat for the other file. | The app identifies the newer file and preserves its exact bytes. The other list can still be opened, changed, and reopened. |
| v1 | Try a bare array, malformed JSON, and a v1 file with one invalid record among valid records. | Each case blocks writes to the affected file, including after retry. The complete original file survives. |
| First real v2 | Open the frozen v1 fixture with the v2 reader. Reopen the resulting file a second time. | Check the target version and every expected field against the v2 decision. IDs, numbers, times, and history order survive. A second open leaves the bytes intact. Upgrading one list leaves the other file intact. |
| First real v2 | Force a failure replacing the source file after conversion. Restore write access and retry. | The failed attempt preserves the v1 bytes. Retry produces the same records as a clean upgrade, with zero duplicate entries and zero launcher requests. |
