# Stop building tag scroll views on every StatusListItem

Context: `docs/investigations/wallet-load-qml-profile.md`, and the scrollbar work in
`issues/0008`.

## What to build

Every `StatusListItem` builds **two tag `StatusScrollView`s** whether or not it has any tags.
That is where roughly 36 of the 40 flickables in a wallet-section load come from — and each
flickable carries scrollbars, which is what made the scrollbar work in `issues/0008` worth
doing in the first place.

Defer them so an item with no tags builds neither.

This is deliberately filed separately from the other leaf-cost work because it is **an API
change, not a local fix**: `tagsModel`, `tagsCount` and `statusListItemInlineTagsSlot` are
aliases into that subtree, and an alias into a deferred subtree does not work. Expect to
change the component's public surface, and expect call sites across the app to need
checking. That is the reason to do it carefully, not a reason to avoid it.

`StatusListItem` is used everywhere. Items with tags must look and behave exactly as they do
today, including inline tag layout, overflow scrolling, and anything that reads the slot.

## Acceptance criteria

- [ ] A `StatusListItem` with no tags builds neither tag scroll view
- [ ] Items with tags are visually and behaviourally unchanged, including overflow scrolling — verified on-screen
- [ ] Whatever replaces the `tagsModel` / `tagsCount` / `statusListItemInlineTagsSlot` aliases is documented, and every call site in the app is updated
- [ ] The flickable count in a wallet-section load is reported before/after
- [ ] `objects_settled` drops; count gates re-recorded with the delta explained
- [ ] StatusQ list-item tests pass, with new coverage for the deferral
- [ ] Storybook functional suite unchanged against its recorded baseline

## Blocked by

- `issues/0008-scrollbar-visibility-js.md` (done)
