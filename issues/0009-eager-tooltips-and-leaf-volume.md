# Stop building tooltips nobody has hovered

Context: `docs/investigations/wallet-load-qml-profile.md`.

## What to build

A warm wallet-section load creates **115 `ToolTip` objects** — for a section showing 8
accounts and 18 asset rows, with no pointer over any of them. Tooltips are hover-only UI: none
of them can be needed until a hover happens, and each carries its own `Control` subtree,
background, text item and bindings.

Put tooltip content behind lazy instantiation so a tooltip costs nothing until first hover,
then behaves exactly as it does now. The likely sites are `StatusToolTip` and the components
that embed one per button — `StatusBaseButton` / `StatusFlatRoundButton` and the wallet
controls built on them — but confirm from a capture rather than assuming.

Same load also builds 496 `Text`, 183 `ColorImage` and 106 `Image` objects. Those are the
next tier and are explicitly NOT in scope here: this issue is the tooltip win, which is
self-contained and low-risk. Record what the leaf counts become afterwards so the remaining
tier can be priced.

StatusQ is app-wide. Tooltips must still show on hover, with the same delay, text, placement
and orientation behaviour, everywhere they are used today.

## Acceptance criteria

- [ ] Tooltip objects created during a wallet-section warm load drop to approximately zero, with before/after from a profiler capture
- [ ] The first hover still produces a correct tooltip with unchanged delay, text and placement
- [ ] Orientation/placement logic still works, including the cases that read geometry at creation time
- [ ] Verified on-screen, hovering real controls - not only in the bench
- [ ] `objects_settled` in the wallet bench drops; the gate is re-recorded with the delta explained
- [ ] Remaining `Text` / `ColorImage` / `Image` counts recorded so the next tier can be priced
- [ ] Storybook functional suite unchanged against its recorded baseline

## Blocked by

None - can start immediately.
