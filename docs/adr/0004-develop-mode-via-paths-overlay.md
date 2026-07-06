---
status: accepted
date: 2026-07-06
---

# Develop mode switches vendors via a nimble.paths overlay, not nimble develop

Vendors are pinned `URL#hash` nimble requires, and on nimble 0.22.3 a
develop-linked checkout can **never** satisfy a `URL#hash` requirement (the
solver binds specials only through store `nimblemeta.json`; `nimble develop
--add` is silently ignored, and lock+`nimble sync` doesn't help — verified
empirically, see vendor/status-go/AGENTS.md). We therefore implement develop
mode ourselves: entering it materializes the vendor checkout under
`vendor/<name>` and records it in a gitignored overlay file; after any
(stamp-gated) `nimble setup`, the build driver rewrites that vendor's entries
in the generated `nimble.paths` (and derived copies) to point at the checkout.
The build engines already treat a non-store resolved path as build-in-place,
so edits are picked up on the next build with no further machinery.

## Considered options

- **file:// manifest flips** (the pre-iteration interim): proven to work, but
  the flip edits the manifest that owns the pin — a read-only store copy for
  transitive vendors, forcing a develop cascade up the parent chain (nimble
  enforces this: file:// requires are legal only at top level or inside
  file://-reached packages); a sibling `URL#hash` pin next to a file://
  requires makes BOTH silently vanish from nimble.paths; and tracked
  manifests go dirty in every develop session. Kept only as the documented
  escape hatch for the rare case the overlay cannot cover.
- **Patched nimble**: fixes the binding at the source but puts a nimble fork
  in every developer's toolchain, contradicting the standing "the dev
  environment owns nim+nimble" direction. Pursued as upstream PRs only.
- **Registry + name-form requires** (name-form DOES accept develop links):
  requires publishing packages to the nimble registry — out while all work
  stays local.

## Consequences

- Dependency **resolution still reads the pinned manifest**, not the
  checkout's. Editing a developed vendor's own `requires` therefore does not
  take effect; the driver compares the checkout's manifest against the pinned
  store copy at setup time and fails loudly with escape-hatch instructions on
  divergence. Silent drift is the one failure mode this mechanism must never
  have.
- ADR 0003's FORCE-delegation + compare-before-copy semantics become the
  develop-mode arm of rebuild gating; pinned (default-mode) vendors are
  instead stamp-skipped entirely (stamp = resolved store path + target triple
  + flag set). This narrows ADR 0003's scope; it does not violate it.
- If a future nimble makes develop links satisfy `URL#hash` requires (and
  drops the ~46 s per-invocation task tax), the overlay collapses into
  `nimble develop` and the driver tasks can promote to native nimble tasks —
  the UX (`develop <vendor>` / `undevelop <vendor>`) is designed to survive
  that swap unchanged.
