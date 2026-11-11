# Pull request checks and code review

## GitHub Actions

The `CI` workflow runs on every pull request, pushes to `main`, and manual
dispatches. It uses a read-only repository token and requires no project secrets.
New commits cancel the previous run for the same PR.

| Check | What it verifies |
| --- | --- |
| Core tests (Swift 5.9, Linux) | The Foundation-only core and its contracts on the minimum supported Swift toolchain |
| Test on Apple Silicon and package macOS apps | Core, view model, and stubbed system adapter tests; shell syntax; arm64 + x86_64 release builds; bundle and signature verification |
| PR checks | Both jobs succeeded; a failed, cancelled, or skipped dependency cannot pass this check |

The macOS job publishes both verified app archives for 14 days. See
[manual-testing.md](manual-testing.md) for the device checks that CI cannot cover.

To require CI before merging, configure a rule for `main` in GitHub repository
**Settings → Rules → Rulesets** (or branch protection): require a pull request and
the `PR checks` status check. Select the check after its first run. This is a
repository setting; adding the workflow does not enable merge protection.

## Codex automatic code review

The root [AGENTS.md](../AGENTS.md) contains the review rules derived from
[architecture.md](architecture.md), including number safety, explicit call
intent, asynchronous handoff, privacy, and macOS compatibility.

Automatic review is configured in Codex, separately from GitHub Actions:

1. Open [Codex code review settings](https://chatgpt.com/codex/settings/code-review)
   with the GitHub account that has push or admin access to `Andriikym/callbar`.
2. Choose `Andriikym/callbar`, enable **Automatic review** under **Review code**,
   and select all PRs. Choose a review trigger that includes new commits if that
   option is available in the account.
3. Open a PR and verify that Codex posts a review for the current revision. A
   one-off review can also be requested with `@codex review` in a PR comment.

The rules file alone does not turn automatic reviews on. A manual review proves
that the integration works, but does not confirm the automatic-review setting.
Codex review also does not replace required CI or a human merge decision.

Official setup instructions:
[Review GitHub pull requests with Codex](https://developers.openai.com/codex/integrations/github/).
