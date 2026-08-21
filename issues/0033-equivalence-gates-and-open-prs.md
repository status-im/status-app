# Verify the extraction was faithful, then open the PRs

Final slice. The three extractions each verified themselves in isolation; this one
proves that **together** they contain exactly the fat branch's production code and
nothing else, then opens the PRs.

Two agents in sequence: an **executor** who runs the gates and opens the PRs, then an
**adversarial reviewer** who re-runs the gates independently and reads the PR
descriptions as a reviewer would.

## Why both gates are needed

Gate 1 catches **under-subtraction** — a bench-hunk strip that took a production line
with it. Gate 2 catches **over-inclusion** — harness that came along for the ride.
Neither catches the other.

## Gate 1 — nothing lost

Build a throwaway tree and compare production content against the fat branch:

    git checkout -b scratch/equiv tests/red-stack-21975
    # cherry-pick all 11 extracted commits onto it
    git diff scratch/equiv feat/storybook-wallet-loader -- <the 27 production files>
    # expect: empty

**The pathspec must be the explicit 27-file list.** Two traps:

- `Makefile` is changed *only* by dropped bench commits. Including it guarantees a false positive.
- A bare `ui/` pathspec is invalid: the two trees have different bases (`bb8c753f7c` vs
  `120bbbf6ed`) and the red-stack rewrite in between changed AppMain, ProfileLayout,
  StatusStackModal, Constants.qml and ~19k lines of i18n. It touches **none** of the 27,
  which is exactly why restricting to them makes the comparison valid.

The 27 files are the union of what the eleven keepers touch outside `storybook/`; it has
been verified to cover every production file the fat branch changed, so nothing is lost
by construction if the cherry-picks landed faithfully.

**An empty Gate 1 is what carries the device verification.** It means the production
bytes in the three branches are identical to the tree already installed and driven on
the Redmi A5 with a real profile — skeleton-to-content handoff confirmed, both delegate
shells rendering real rows. No device re-run is needed for these three branches.

## Gate 2 — nothing extra

Per branch:

    git diff --name-only tests/red-stack-21975 <branch> -- storybook/

Nothing under `storybook/mocks/` or `storybook/benches/`, no `WalletLoaderPage.qml`, no
`WalletSectionMock`, no generated wallet backend. Since `storybook/benches/` does not
exist on `tests/red-stack-21975` at all, its mere appearance is an immediate failure.

Expected additions are only the mock-free unit tests listed in 0030 and 0032.

## Then open the PRs

Three PRs, all based on `tests/red-stack-21975`:

    perf/statusq-leaf-cost       (0030)
    perf/incubation-duty-cycle   (0031)
    perf/wallet-load             (0032)

Each description should carry: what the change does, the measurements, the provenance
note that the bench is not in the PR, and its specific caveat —

- **leaf-cost**: StatusQ-wide, touches every button, list item, combo box, menu item and
  scrollbar in the app
- **duty-cycle**: reads as a follow-up to approved-but-unmerged PR #21921, which owns the
  file and introduced the constant; cannot reach master before it
- **wallet-load**: the detail-view deferral has no automated coverage, and 0028 blocks
  manual reach of that screen

State plainly in each: nothing here reaches master before PR #21998 and its chain land,
since `tests/red-stack-21975` is itself mid-stack under issue 21975.

## Reviewer brief (adversarial, fresh context)

Re-run both gates yourself rather than trusting the report. Then read each PR description
as an outside reviewer with no knowledge of this session: is the change justified by what
is written, is the caveat stated honestly rather than buried, and does any measurement
appear reproducible when it is not?

## Acceptance criteria

- [ ] Gate 1 output empty over the explicit 27-file pathspec
- [ ] Gate 2 clean on all three branches
- [ ] `scratch/equiv` deleted afterwards
- [ ] Three PRs open against `tests/red-stack-21975`, each with its caveat stated
- [ ] No PR opened for `feat/storybook-wallet-loader`
- [ ] PR #21921 untouched
- [ ] Adversarial review completed and its findings resolved or explicitly declined

## Blocked by

- 0030, 0031, 0032
