# Cut StatusScrollBar's visibility JavaScript

Context: `docs/investigations/wallet-load-qml-profile.md`.

## What to build

A qmlprofiler capture of a warm wallet-section load shows `StatusScrollBar` spending
**~7.9ms of pure JavaScript** inside a ~181ms window — `resolveVisibility`
(`StatusScrollBar.qml:30`) evaluated **125 times** for 5.73ms of self time, plus
`thumbActive` (`StatusScrollBar.qml:47`) 50 times for 2.19ms. Related, and probably the same
root: `StatusScrollView.qml` contributes another ~2.9ms across `active` and `visible`
expressions evaluated ~22-75 times each.

Nothing in a section load should re-evaluate scrollbar visibility a hundred times. Find why
it re-runs that often — most likely a binding depending on a value that churns during layout
(content size, viewport size, or a policy derived from both) — and make it settle.

This is a StatusQ component used across the whole app, so the win is not wallet-specific and
neither is the blast radius. Behaviour must not change: scrollbars appear, hide and animate
exactly as they do today, in both scroll policies and both orientations.

## Acceptance criteria

- [ ] The number of `resolveVisibility` evaluations during a wallet-section warm load drops substantially, with before/after from a profiler capture
- [ ] Why it was re-evaluating is stated — the actual dependency that churned, not a guess
- [ ] Scrollbar show/hide/auto-hide behaviour is unchanged, verified on-screen in both orientations
- [ ] StatusQ scrollbar/scrollview tests pass; new coverage if the fix has a testable invariant
- [ ] The storybook functional suite is unchanged against its recorded baseline
- [ ] Before/after numbers recorded in the profiling doc

## Blocked by

None - can start immediately.
