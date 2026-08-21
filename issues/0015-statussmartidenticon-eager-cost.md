# Cut StatusSmartIdenticon's per-instance eager cost

> **CLOSED 2026-08-20 — measured, and not worth doing.**
> The settled wallet section holds **23** identicons, not the 49 the profiling doc reports:
> that capture counts creations across the whole run, including subtrees torn down again.
> Of the 23, **21** have a caller-supplied `asset`, so the default-constructed
> `StatusAssetSettings` is genuine waste — and it is **21 objects, 0.34% of `objects_settled`**.
> Too small to justify touching a component used across five sections.
>
> The real cost in this component is the badges: `badge` + `bridgeBadge` are **11.0 objects
> per instance, 4.1% of `objects_settled`** — twelve times the default-`asset` waste. They stay
> anyway: both are public aliases that ten call sites write into with grouped assignments
> (`badge.border.color:`, `bridgeBadge.image.source:`), and an alias into a deferred subtree
> does not work. Deferring them is an API change across ten call sites for 4% of a count on a
> surface already inside budget.
>
> Re-open only if the badge aliases are being reworked for another reason.

Context: `docs/investigations/wallet-load-qml-profile.md`. Flagged as unclaimed by the agent
that did `issues/0008`-`0010`; no other issue covers it.

## What to build

A warm wallet-section load builds **49 `StatusSmartIdenticon`s** — one per account row, per
token row and per avatar site. In the profiler capture it is the third-largest inclusive item
in the window, and 30 of the 49 are built inside the section's two `StackView`s.

Three eager costs are visible in the component itself (`165` lines, root is a synchronous
`Loader`):

1. **A default-constructed `StatusAssetSettings`** — `property StatusAssetSettings asset:
   StatusAssetSettings { ... }` builds a settings object on **every** instance, including the
   ~all of them whose caller supplies its own. The default is a fallback that almost nobody
   uses and everybody pays for.
2. **`StatusBadge` at line 129 and the bridge badge at line 143** are declared inline and
   aliased out as `badge` / `bridgeBadge`. **Probably not worth touching** — a peer agent
   measured the pair at ~11 objects per instance, not the ~31 first assumed. Against that,
   deferring them means breaking public aliases (see the hazard below). Verify the count
   yourself before spending anything here; the expected answer is "leave them".
3. The root `Loader` is **synchronous**. Whether it should be asynchronous is a real question
   but not an obvious yes — see the hazard below.

Fix what the capture actually shows, in that order. The first is the cleanest: a default
value that every caller overrides is pure waste, and removing it is local to the component.

## Hazards

- **Do not reflexively make the root `Loader` asynchronous.** These sit inside list delegates,
  and the lesson from `issues/0007` is that a delegate's own async loader interacts with the
  view's `AsynchronousIfNested` behaviour in ways that need measuring, not assuming. An
  identicon that pops in one frame late in a scrolling list is a visible regression.
- `badge` and `bridgeBadge` are **public aliases**. An alias into a deferred subtree does not
  work — the same wall `issues/0014` hits with `StatusListItem`'s tag slot. If deferring the
  badges means changing the public surface, price that against the win before committing to it.
- `StatusSmartIdenticon` is used across HomePage, Communities, Chat, Wallet and Profile.
  Avatars, letter identicons, images and icons must all render exactly as today, including the
  hover behaviour exposed via `hovered`.

## Measurement

Judge on **counts**, not profiler milliseconds — that document's ms over-attribute object
creation, and a ~17ms attribution in it proved unresolvable in a Release A/B. Report
`StatusAssetSettings` instances, badge instances, and `objects_settled` in the wallet bench.
Any time claim needs a Release A/B with alternated arms and the spread reported.

## Acceptance criteria

- [ ] Instances that supply their own `asset` no longer build a default `StatusAssetSettings`, verified by count
- [ ] Badge construction is measured; deferred only if the count justifies breaking the public aliases, otherwise explicitly left alone with the number recorded
- [ ] `objects_settled` drops; count gates re-recorded with the delta explained
- [ ] Identicons render identically across all four source components (loading, letter, image, icon), verified on-screen in at least two different sections
- [ ] Hover behaviour via `hovered` is unchanged
- [ ] If the root `Loader` is made asynchronous, pop-in inside a scrolling list is measured and shown not to regress; otherwise state why it was left synchronous
- [ ] StatusQ tests pass; storybook functional suite unchanged against its recorded baseline

## Blocked by

None - can start immediately. Overlaps `issues/0014` only in the alias-into-deferred-subtree
problem; if both are in flight, coordinate on that pattern.
