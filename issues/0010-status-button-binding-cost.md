# Reduce StatusBaseButton's per-instance binding cost

Context: `docs/investigations/wallet-load-qml-profile.md`.

## What to build

`StatusBaseButton` is the heaviest single file by self time in a warm wallet-section load
(**8.66ms**), spread across expressions evaluated roughly 20 times each: `iconOnly`
(`:113`), `active` (`:258`), `iconSize` (`:117`). `StatusIcon` adds a further ~6.9ms, with
`onIconChanged` firing 66 times and 183 `ColorImage` creations.

Twenty evaluations of the same expression per load suggests bindings re-firing as
dependencies settle during layout rather than being computed once. Find the churn, and make
these settle - or make the expressions cheap enough that settling does not matter.

StatusQ is app-wide: every button in the product goes through this file. Any change has to
preserve icon/text layout, sizing and enabled/hover/checked visuals exactly.

## Acceptance criteria

- [ ] Evaluation counts for `iconOnly`, `active` and `iconSize` during a warm load drop substantially, with before/after from a profiler capture
- [ ] The churn source is named with evidence
- [ ] Button visuals are unchanged across icon-only, text-only and icon+text configurations, in normal/hover/pressed/checked/disabled states
- [ ] `StatusIcon`'s `onIconChanged` firing count is reported, and addressed if it shares the same cause
- [ ] StatusQ button tests pass; storybook functional suite unchanged against its recorded baseline
- [ ] Before/after recorded in the profiling doc

## Blocked by

None - can start immediately.
