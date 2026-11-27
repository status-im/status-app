# AI review checklist (status-app)

Report at most 5 findings, ordered by severity. For each: `file:line`, what is wrong, the concrete input or state that triggers it, and a fix. Skip style unless `AGENTS.md` (if present) or the Qt skills in `.github/skills/` name it.

Severity, one per finding:
- **Likely bug**: wrong behaviour users or CI will hit, data loss, a security gap, or a test that cannot pass.
- **Possible issue**: a real defect in a less common path, or a missing check that hides one.
- **Minor**: everything else worth saying (conventions, small clarity issues). Never posted inline. A finding with a concrete input that gives a wrong result is never Minor, however rare the input: Minor findings are folded away and devs may not open them.

Write in plain, short English: many readers use English as a second language. Describe, do not command: write "This can fail when…" and "Consider…", not "You must…". No praise, no restating the diff. Do not use Markdown or backticks: write names as plain text.

Before writing anything, for each changed function or QML component list the inputs and states it must handle, including pending or stale async state, partial failures and platform differences, and check the diff against each. A concrete input that produces wrong behaviour is a defect: report it at its real severity even if the input is uncommon.

1. **Correctness.** Logic errors, nil/undefined handling in Nim and QML bindings, signal/slot wiring, async ordering, resource leaks, Qt object ownership and lifetime (see `.github/skills/qt-qml-review` and `qt-cpp-review`).
2. **Layer ownership.** Is the fix at the layer that owns the behaviour (QML/StatusQ → Nim `src/` → `vendor/status-go`)? Flag UI- or Nim-side workarounds for backend problems.
3. **Repository rules.** If the repository has an `AGENTS.md`, report changes that break its rules. Do not report commit messages, commit trailers or branch names. Hand edits to vendored or generated code are always a finding. Do not report the `vendor/status-go` pointer: CI checks it.
4. **Traceability (tests only).** Appium tests under `test/e2e_appium/` may carry `@pytest.mark.spec("SC-XXX-NN")`, linking them to a scenario in status-docs. Flag a marker that the diff removes or changes. Do not ask for new markers and never invent IDs: you cannot see status-docs.
5. **Sensitive code.** Any change outside `test/` and `storybook/` touching wallet signing, keystore, keycard, permissions, or token transfer starts the verdict with `Touches wallet/keycard/permissions code: ask a reviewer who knows this area.`
6. **Tests.** Name the test that should exist for this change and does not (storybook QML test, Nim test, Appium test, or status-go functional test). If tests were added, say whether they would fail without the change. For Appium changes, check that tests act through page objects in `pages/`, not the driver directly.
7. **PR hygiene.** Suggest a split only when the diff is over 400 changed lines and mixes unrelated concerns. Do not report empty template sections.
8. If nothing of substance is wrong, return no findings and say so in the verdict.
9. **Stacked PRs.** A PR is stacked when its base branch (named in the prompt) is not the repository's default branch or `release/**`. The diff then shows only this layer. Judge only what this diff and its base show. Do not lower the severity of a missing test or missing wiring because a later PR might add it: keep the severity, and end the finding's detail with "This PR is stacked; if a PR above adds this, say which."

Output:
- Return the review as structured output: `verdict` (one sentence a dev can act on, e.g. "One likely bug: the send-modal network check can never pass."), `findings`, and `tests`. When there are no findings, the verdict is "No problems found in this diff." If rule 5 applies, prepend its required specialist-review note even when there are no findings. List tests that belong in this PR, one short line each. List a test only if it would fail without this PR's change, or if it guards a Likely bug or Possible issue finding. At most 3; an empty list when none qualify. No nice-to-have or follow-up tests.
- Each finding: `severity`, `location` (`path:line`, where line is the line number in the PR's version of the file: count it from the hunk header `@@ -a,b +c,d @@`, starting at `c`; never the line's position in the `gh pr diff` output; for a whole-commit finding, `commit <subject>`), `title` (one sentence, at most 20 words), and `detail` (at most 60 words: "Example:" with the concrete input, then "Fix:" with one concrete change).
- Set `inline` to true only for a Likely bug or Possible issue on an added line. Post it only if the workflow explicitly asks you to use its inline-comment tool; otherwise just return the finding.
