# Wallet perf work → PRs on tests/red-stack-21975

Source: `feat/storybook-wallet-loader` @ 767a811f0f ("the fat branch").
46 commits over base `bb8c753f7c` = 30 storybook harness + 11 production + 5 merges.

Drop: all storybook wallet harness (generated mock backend, WalletLoaderPage,
benches, baselines, Makefile bench targets) and any test needing it.
Keep: the 11 production commits.

## Shape — 4 PRs

    tests/red-stack-21975 ──┬── fix/asset-detail-tap        (0028)  merges first
                            │      └── perf/wallet-load     (C)
                            ├── perf/statusq-leaf-cost      (A)
                            └── perf/incubation-duty-cycle  (B)

A, B, C have **zero file overlap** — independent, any merge order.
The only edge: 0028 and C both edit `onAssetClicked` in RightTabView.qml.

red-stack is itself mid-stack: pushed @120bbbf6ed, open PR #21998 →
`perf/mobile-section-extras`, issue 21975. Nothing reaches master before that chain.

## Commit lists (chronological within group — order matters)

**A — perf/statusq-leaf-cost** (StatusQ-wide; touches every button/list-item/scrollbar)
    0d645404cd  perf(StatusQ): build control tooltips on the first hover
    7109ea7912  perf(StatusQ): let StatusScrollBar resolve its own policy
    8ad3cfcccd  perf(StatusQ): build the button ripple on the press that needs it
    82a653cb2e  perf(StatusQ): build the remaining ripples on the press that needs them
    b2dabd8162  perf(StatusQ): build the StatusListItem tag rows only when there are tags
  Intra-group order is load-bearing: 0d645404cd+8ad3cfcccd both edit StatusBaseButton.qml;
  82a653cb2e+b2dabd8162 both edit StatusListItem.qml.

**B — perf/incubation-duty-cycle**
    d00dbf20c4  perf(statusq): run gentle incubation at a 50% duty cycle
    + the tst_incubationcadence.cpp hunk SPLIT OUT of f905357a45
  f905357a45 is subject-labelled `test(storybook)` but carries a correction to the
  C++ test's stated rationale (it claimed the bite was the stall floor — disproved).
  Drop its bench + Makefile hunks, keep the .cpp hunk.
  Do NOT touch PR #21921 (approved, unmerged, owns externc.cpp:101).

**C — perf/wallet-load** (based on fix/asset-detail-tap)
    1cf5cf026a  perf(wallet): make the assets list's first fill preemptible
    1bf95022e8  perf(wallet): latch the token row's two warning buttons off
    2053b6b3de  perf(wallet): defer the two detail views behind async loaders
    b0cfb4460c  perf(wallet): latch the always-hidden subtrees off the asset detail
    7bfb8cb905  perf(wallet): make the accounts list's first fill preemptible

**PR 0 — fix/asset-detail-tap** — content not yet determined, see Open items.

## Strip rules (apply per cherry-pick)

1. Every `storybook/benches/**` hunk. red-stack has NO storybook/benches dir —
   these hunks would create files that shouldn't exist. Affects 9 of 11 keepers.
2. `storybook/pages/WalletLoaderPage.qml` — 3-line hunk in 82a653cb2e only.
3. Makefile — bench targets, only in dropped commits (+ f905357a45's split).

No dropped commit touches any file a keeper edits, so cherry-picks are otherwise clean.

## Test rescue

`tst_WalletDetailViewDeferral.qml` is the ONLY test needing the full wallet mocking
(WalletSectionMock/WalletSectionPopupsMock) and the ONLY coverage of 2053b6b3de.
Rewrite against pre-existing stubs + standard mocking (plain ListModels).
- red-stack keeps `storybook/stubs/AppLayouts/Wallet/stores/RootStore.qml` (96 lines)
  because the commit that retired the stubs is dropped.
- Extend it with: setCurrentViewedHolding, resetCurrentViewedHolding, walletAssetsStore.
- Do NOT export RightTabView in views/qmldir — it carries 54 direct RootStore
  singleton refs; exporting advertises a component that can't stand alone.
- 5 cases to preserve: not-built-on-load; nav resolves after incubation;
  last-request-wins mid-incubation; viewed-holding reset on leaving each detail view.

Every other new/edited test is mock-free and rides along unchanged.

## Commit messages

- KEEP all measurements. They are the justification; without them several commits
  read as unmotivated churn across shared components.
- KILL every `issues/NNNN` and `docs/investigations/...` reference (untracked, never merging).
- ADD one provenance line: measured on the offscreen storybook wallet bench, not part
  of this PR, see branch `feat/storybook-wallet-loader`.

## Docs

None ride along. CONTEXT.md (273), ADR 0008 (103), wallet-load-benchmarks.md (1839),
wallet-load-qml-profile.md (123), issues/ (29 files) all stay off the four PRs.
Park them with the harness on `feat/storybook-wallet-loader`.
Note: CONTEXT.md is untracked everywhere yet committed CLAUDE.md lists it as a Key Doc —
pre-existing dangling reference, its own small PR later, trimmed to surviving terms.

Push `feat/storybook-wallet-loader` un-merged so the provenance references resolve.

## Verification

**Gate 1 — nothing lost.** Restricted to the 27 production files only:
    git diff scratch/equiv feat/storybook-wallet-loader -- <27 files>   # expect empty
  Must be restricted: the two trees have different bases (bb8c753f7c vs 120bbbf6ed) and
  the red-stack rewrite touched ui/ (AppMain, Profile, Constants, 19k i18n) — but touches
  NONE of the 27. Makefile must be excluded (changed only by dropped commits).
  Empty ⇒ production bytes identical to the tree already device-verified on the Redmi A5
  ⇒ device verification transfers, no re-run.

**Gate 2 — nothing extra.**
    git diff --name-only tests/red-stack-21975 scratch/equiv -- storybook/
  Expect only the unit-test files + AssetsDetailsHeaderPage.qml.
  Nothing under storybook/mocks/, storybook/benches/, no WalletLoaderPage.qml.

Gate 1 catches under-subtraction, Gate 2 over-inclusion. Neither catches the other.

**Per branch:** storybook QmlTests differentially vs a red-stack baseline (known
pre-existing: ChatTextArea/ChatTextView pair — 1869 passed, 2 failed, 5 skipped);
qml-lint; StatusQ ctest for B (tst_incubationcadence).

**Device:** only PR 0 (net-new code). Rescued deferral test: host-green is the bar.

## Open items

1. **0028 fix content.** Findings so far: the detail view reads 19 roles off tokenGroup;
   terminal assetsModel supplies 12, the grouped/joined side uniquely supplies
   balances/decimals/description/detailsLoading/marketDetails/tokens/websiteUrl.
   So the handler's merge is LOAD-BEARING — "read the group from assetsModel instead"
   would silently blank 7 fields. Both pipelines key on the same groupKey
   (assets_aggregator.nim:101 copies g.key), pointing at EMPTY not mismatched.
   Likely mechanism: after the terminal-model rewire nothing drives the legacy
   walletSectionAssets.groupedAccountAssetsModel; ActivityFiltersStore is its only
   remaining consumer and is lazily constructed.
   NEXT: print groupedAccountAssetsModel.count at tap time on device. One-line probe.
   Bug is on MASTER (RightTabView.qml:332 feeds assetsModel, :449 queries the grouped
   model, :459 throws) — not introduced by 2053b6b3de.
2. **Branch-name collision check** — `perf/statusq-leaf-cost` was a side-branch name on
   the fat branch; confirm before creating.
