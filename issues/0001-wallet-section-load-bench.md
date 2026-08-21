# Wallet section load bench

Context: `docs/investigations/wallet-load-benchmarks.md`, `docs/adr/0008-offscreen-storybook-benches-as-wallet-load-gate.md`,
glossary section "Surface load benchmarking" in `CONTEXT.md`.

## What to build

The first load benchmark for a surface, built end-to-end around the wallet section only.
An offscreen storybook `qmlTest` brings up the real `WalletLoader` against the whale
profile (`WalletSectionMock` defaults), records the load staircase, runs a stall probe
through the window, counts what gets instantiated, appends a row to a checked-in TSV,
and fails on the deterministic metrics. A `make` target runs it and prints the staircase
table.

Deliberately un-generalised: the probe/TSV plumbing lives with this one bench. It gets
extracted into a reusable helper in the popup-benches slice, once there is a second
consumer.

Staircase stamps for this surface, measured from `WalletLoader.active = true`:

- `t_skeleton` — skeleton chrome visible
- `t_ready` — `WalletLoader.status === Loader.Ready`
- `t_content` — **and** `walletAccountsListViewLoader` and `mainViewLoader` both Ready

Metric roles: `t_content` is the headline and is recorded, not asserted. Instantiation
counts and the stall count are hard-gated. Max stall is recorded.

Harness commits must touch only `storybook/` and test files — no production QML — so they
cherry-pick onto master once the perf stack lands.

## Acceptance criteria

- [ ] A storybook qmlTest instantiates `WalletLoader` at whale scale with the popups mock's store wiring
- [ ] The three staircase stamps are recorded, in host units, with no pre-multiplication
- [ ] A 1ms-interval stall probe runs through the window; the count of gaps over 4ms and the max gap are both recorded
- [ ] Instantiated object / delegate counts are recorded
- [ ] The test hard-fails on a change in instantiation counts, and on any stall over the 4ms threshold
- [ ] Staircase timings and max stall are written to a checked-in TSV and are NOT asserted
- [ ] A `make` target runs the bench and prints the staircase table
- [ ] Deliberately regressing the section (e.g. forcing a subtree to build eagerly) makes the gate fail, and the failure message names the metric
- [ ] The baseline TSV is committed with its recorded numbers
- [ ] No production QML is touched

## Blocked by

None - can start immediately.
