# Roll the deferred ripple out to the other StatusQ controls

Context: `docs/investigations/wallet-load-qml-profile.md`, and the `StatusBaseButton` work in
`issues/0010`.

## What to build

`StatusBaseButton` now builds its `StatusRipple` behind a `Loader` activated on the first
press — six QObjects (Item, Connections, QtObject, Rectangle, two NumberAnimations) that
exist purely to animate an interaction that may never happen.

Only ~13 of the 35 ripples in a wallet section belong to a `StatusBaseButton`. The rest are
declared by `StatusListItem`, `StatusComboBox`, `StatusItemDelegate` and `StatusMenuItem`,
each driving its own through a `pressRipple()` helper. The same `Loader` fits there and is
priced at roughly another 110 objects on this surface.

Follow the shape already established rather than inventing a second one. The load-bearing
detail from `issues/0010`: `AbstractButton` sets `pressed` before it emits `pressed()`, so a
ripple created on first press is connected in time to catch the press that created it. Any
control whose press signal ordering differs needs that checked, not assumed.

## Acceptance criteria

- [ ] Each of the four controls builds its ripple only on first press
- [ ] Press feedback is unchanged on all four, verified on-screen — ripple starts at the pointer, clips to the control's radius, collapses on release
- [ ] A disabled or non-interactive control never builds a ripple
- [ ] Tests assert both the deferral and the first-press feedback, following `tst_StatusButton::test_pressFeedback`
- [ ] Press-signal ordering is verified per control, not assumed from `StatusBaseButton`
- [ ] `objects_settled` drops; the count gates are re-recorded with the delta explained
- [ ] Storybook functional suite unchanged against its recorded baseline

## Blocked by

None - `issues/0010` is done and is the pattern to follow.
