# `Utils.getNetworkName()` renders an empty network for an unknown chain

Context: `docs/investigations/wallet-load-benchmarks.md`, "On-screen pass on the collectibles
path". Found while fixing the storybook harness in `issues/0019`; this one is production code.

## What to build

`Utils.getNetworkName()` is a hardcoded `switch` over chain ids that returns `""` for any
chain it does not know. Its inputs are not static:

- `unsupportedCollectibleChains` arrives from a status-go RPC,
- the active-network list is equally dynamic.

So a chain that status-go both activates *and* reports as collectible-unsupported, but which
predates no case in that switch, renders `CollectiblesNotSupportedTag` as **"Displaying
collectibles on  is not currently supported by Status."** — with an empty `%1`.

This is not reachable with today's shipped chain list, which is why nobody has seen it. It is
also the only way that string can go empty in production: the same empty text in storybook
turned out to be a harness gap with a different cause entirely.

Decide the right shape rather than adding a case to the switch. Options worth weighing: derive
the name from the networks model that already carries it, fall back to the chain id when no
name is known, or suppress the tag when it cannot name anything. Adding one more hardcoded
case fixes today's list and leaves the defect.

Worth checking while in there: every other caller of `getNetworkName()`, since the same empty
string will be flowing into any of them that take a dynamic chain id.

## Acceptance criteria

- [ ] An unknown chain id no longer produces an empty network name anywhere the function is used
- [ ] The chosen fallback is stated and justified — name from the model, chain id, or suppress
- [ ] Other `getNetworkName()` call sites audited for the same exposure
- [ ] Covered by a test that passes a chain id the switch does not know
- [ ] Storybook functional suite unchanged against its recorded baseline

## Blocked by

None - can start immediately.
