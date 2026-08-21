# Popup gentle hints and precompile

Context: `docs/investigations/wallet-load-benchmarks.md`,
`docs/adr/0008-offscreen-storybook-benches-as-wallet-load-gate.md`.

## What to build

Two changes that protect the popup open animation rather than reduce work:

1. Bracket each modal's enter transition with `IncubationHints.pushGentle()` /
   `popGentle()`, so the incubation controller keeps its bites small while the animation
   runs. Today only `StatusSectionLayout` does this, for panel switches.
2. Precompile the modal URLs when the wallet section becomes ready, the way section URLs
   are already front-run, so opening pays instantiation but not compilation.

**This slice is not gate-verifiable, and that is expected.** The benchmark harness runs
offscreen with a timer-metered incubation controller, so it cannot see anything that only
manifests against a real render loop. Gentle hints may show as no change, or as a small
regression, in the gated numbers. Verification is a deliberate on-screen storybook run —
`WalletLoaderPage` already has a `profile-exit` mode for attaching `qmlprofiler` — comparing
frame pacing across the open animation with and without the change.

The issue is done when the on-screen evidence exists and is recorded, not when a test
turns green. If the gated numbers move in the wrong direction, say so in the working doc
rather than tuning the bench to hide it.

## Acceptance criteria

- [ ] Modal enter transitions push and pop a gentle incubation hint, balanced on every exit path including cancel and error
- [ ] Hints are not left held when a modal is destroyed mid-animation
- [ ] Modal URLs are precompiled when the wallet section reaches ready
- [ ] Precompilation does not delay the section's own staircase — section `t_content` is unchanged or better
- [ ] An on-screen storybook run records frame pacing across the open animation, before and after
- [ ] The verification method and its results are written into the working doc
- [ ] Any movement in the gated numbers is reported rather than suppressed

## Blocked by

- `issues/0003-popup-load-benches.md`
