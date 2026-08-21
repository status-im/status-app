# Popup deferral fixes

Context: `docs/investigations/wallet-load-benchmarks.md`.

## What to build

Cut the measured cost of opening the send, receive and swap popups by deferring subtrees
the user cannot see yet — inactive tabs, sticky headers, collapsed advanced sections,
closed dropdown contents. Prioritise strictly by what the popup benches measured, not by
the order the popups are listed anywhere.

This is the tool that has historically moved this code: the previous round took roughly a
second off send-modal open with defer-until-needed latches and by killing an adaptor whose
cost scaled with the global token universe rather than with what the user owns. Neither
win involved a skeleton. Skeletons stay available but are the last resort here, and only
where the primary content is a long list — a skeleton inside a modal risks resizing the
dialog on swap, adds flicker whenever it lives shorter than the open animation, and
disturbs initial focus.

Deferral latches must be monotonic and must OR together every surface that can reveal the
deferred content — the main header and the sticky header have divergent tab state, and a
latch that only listens to one of them will strand the user on an empty panel.

Look specifically for work done by the *handler* rather than by the modal tree. Handler-built
adaptors are invisible to a bench that only instruments the modal, and that is exactly where
the last big offender was found.

## Acceptance criteria

- [ ] Fixes are chosen by measured cost, and the ranking that drove the choice is written down
- [ ] Each fix is its own revertible commit with its before/after numbers in the message
- [ ] Every deferral latch is monotonic and covers all reveal surfaces, including the sticky header
- [ ] Deep-link / preselect entry into each popup still resolves correctly when content is deferred
- [ ] Initial focus behaviour is unchanged — first keystroke after opening send still lands in the amount field
- [ ] Gated instantiation counts drop for the popups touched
- [ ] Baseline TSV updated alongside each fix
- [ ] Any fix that adds indirection is sanity-checked at small N before landing

## Blocked by

- `issues/0003-popup-load-benches.md`
