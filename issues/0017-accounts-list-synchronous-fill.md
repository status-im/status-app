# The accounts list fills synchronously too

Context: `docs/investigations/wallet-load-benchmarks.md`, the block table at the end of
"The residual warm block is `StackView.initialItem`".

## What to build

The wallet section's post-`t_content` block is **12.1 - 13.4ms**, and the sampler is
unambiguous: 22/22 samples in `QSGSoftwareRenderLoop::renderWindow`, 16/22 in `polishItems`,
14/22 in `QQuickItemView` refill → `createItem`, with no probe frames in it. It is the
**accounts** list filling every visible row synchronously — the same `AsynchronousIfNested`
mechanism that made the assets list cost 34.7ms before `issues/0007`.

Apply the shape that worked there: a cheap delegate shell carrying the row's geometry, with
the rich content behind a nested asynchronous `Loader`, so the refill builds shells and the
rows incubate afterwards in metered bites.

`issues/0007` is the pattern — read its commits (`1cf5cf026a`, `1bf95022e8`) before starting,
and match them rather than inventing a second approach.

## Hazards, learned from doing this once already

- **The shell must know its own height without its content**, or `contentHeight`, the
  scrollbar and the scroll position jump as rows fill in. On the assets list this resolved
  cleanly because every row hit `StatusListItem`'s 64px floor; an account row may not. If row
  height is content-derived, that is the hard part of this issue, not a detail. Whatever
  invariant you rely on, **gate it with a test** the way `tst_TokenDelegateShell` does, so a
  future change that makes rows taller fails a test instead of moving the scroll position.
- The accounts list already sits behind a per-tab skeleton, so there will be two loading
  states. Make the placeholder mirror the skeleton so the two read as one handoff.
- Check interaction with delegate recycling and with account reordering.
- **Expect the headline to move against you.** Per `issues/0016`, the controller's 24% duty
  cycle means metered work takes ~4x the wall clock, so removing a 12ms block can add ~35ms
  to `t_first_asset_row_ms`. Report both metrics. If the trade is bad, say so and leave it —
  the assets-list fix was worth it because the block was 34.7ms; this one is a third of that
  and the call is genuinely less obvious.

## Measurement

Release bench A/B, arms alternated, multiple rounds, spread reported. If the arms overlap,
say so. Count gates are exact and will fail — re-record and explain the delta. Ratchets only
move down.

Note a measurement artefact documented in the same table: the block straddling
`t_ready`/`t_content` contains **~3ms of the bench's own probe** (`takeInstantiationCounts()`
walks 4602 objects at the `t_content` stamp). Do not attribute that to the section.

## Acceptance criteria

- [ ] The post-`t_content` block is reduced, with sampler evidence that the refill is no longer synchronous
- [ ] Row height is stable across the shell-to-content transition, and the invariant is gated by a test
- [ ] Both `max_stall_ms` and `t_first_asset_row_ms` reported before/after from an alternated A/B with spread
- [ ] If the trade is net negative under the current duty cycle, that is stated and the change is not landed
- [ ] Account list behaviour unchanged — selection, reordering, recycling — verified on-screen
- [ ] Count gates re-recorded with deltas explained
- [ ] Storybook functional suite unchanged against its recorded baseline

## Blocked by

None - `issues/0007` is done and is the pattern. Consider `issues/0016` first: it decides
whether this trade is worth making at all.
