# Popup load benches — send, receive, swap

Context: `docs/investigations/wallet-load-benchmarks.md`.

## What to build

Load benchmarks for the three wallet popups, at whale scale, on the same contract as the
section bench. `tst_WalletSectionPopups` already opens send, swap, receive and buy against
a full generated profile through the real handler path — this slice turns that reachability
into measurement.

This is also where the harness stops being one-off: extract the probe / staircase / TSV
plumbing from the section bench into a reusable helper now that there are four consumers.
The section bench must keep producing the same numbers after the extraction.

Staircase per popup: start at the handler call (`openSend()`, `launchSwap()`, the receive
signal), `t_content` at `opened` **and** the popup's primary interactive control present.
Budget is 400ms device / 40ms host.

Note for whoever picks this up: the popups run against a whale profile here, whereas the
existing popups test overrides the mock down to a small profile. Those are different
workloads — the bench must use whale, and must not quietly change the workload of the
existing functional assertions.

## Acceptance criteria

- [ ] Staircase, stall probe and instantiation counts are recorded for send, receive and swap at whale scale
- [ ] The probe / staircase / TSV plumbing is a shared helper used by all benches
- [ ] The section bench produces the same numbers before and after the extraction
- [ ] Each popup gets hard gates on instantiation counts and stalls over the 4ms threshold
- [ ] Timings land in the checked-in TSV, unasserted, in host units
- [ ] The existing functional assertions in `tst_WalletSectionPopups` keep their current workload and still pass
- [ ] The `make` target runs the popup benches alongside the section bench
- [ ] Baselines committed

## Blocked by

- `issues/0001-wallet-section-load-bench.md`
