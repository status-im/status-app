---
id: 0006
title: nim-sds per-target subdir artifact packages (upstream veneer)
date: 2026-07-03
tracker: local (GH publication deferred by user)
triage-label: needs-upstream
status: open
---

## Parent

PRD: `docs/superpowers/prds/2026-07-03-statusgo-nimble-package-prd.md`
Design: `docs/superpowers/specs/2026-07-03-sds-from-nimble-resolution-design.md`

## What to build

Upstream nim-sds change: `targets/<flavor>/` subdir artifact packages
(host-static, ios, android-arm64, …) so that

```sh
nimble install "https://github.com/logos-messaging/nim-sds?subdir=targets/ios@#v0.4.x"
```

is one-command provisioning of a cross-compiled `libsds` artifact. Each
subdir package: pinned `requires` on nim-sds matching its own release tag;
`before install` hook that materializes dep paths (nested `nimble setup`),
copies the resolved sds to scratch, runs the sds task for its baked-in
target (NDK/SDK via env, as today); `installDirs = @["build"]` +
`libsds.h` so the artifact lands in the store. Targets coexist because each
subdir is its own package identity (spike-verified).

Also part of this upstream work — **sds build unification**: collapse the
per-target tasks into one parametric build entry point (flag selection in
nim config keyed by `--os`/`--cpu`/defines; per-target tasks become
one-line aliases; the localization postprocess stays in the thin driver —
it cannot be expressed as flags). The subdir hooks and statusgo's engine
(0005) then call the one entry point with target flags instead of
dispatching across task names.

Also file the upstream **nimble** issue recorded in the design spec:
forward target flags to hook evaluation + target-qualified store dirs —
the eventual replacement for the subdir veneer.

## Constraints (spike-verified, see design spec)

- Subdir staging contains only the subdir's files — the artifact hook MUST
  source sds via `requires`, never `../..`.
- Only install hooks fire for bin-less packages; `before install` staging
  outputs are carried by `installDirs`.
- Rev syntax: `?subdir=<path>@#<rev>` (rev last).
- statusgo's make matrix does NOT depend on this issue — develop-linked and
  uncommitted-patch flows keep the direct engine path (issue 0005).

## Acceptance criteria

- [ ] Per-target install proof on the local file-URL harness: host-static +
  one cross target install; artifacts land in the store; targets coexist.
- [ ] Installed host-static artifact passes the localization audit
  (`nm -gU` → only `_Sds*`).
- [ ] A statusgo build can link the store-installed host artifact (manual
  wiring is fine — automatic consumption is out of scope here).
- [ ] Upstream nimble issue drafted (flag forwarding to hooks +
  target-aware store).

## Blocked by

- Upstream: nim-sds patch queue merges (incl. `libsdsStaticMac`
  localization), nim-sds tags releases, `targets/` layout accepted by
  maintainers. GH publication currently deferred by user — prepare
  patches/issue text locally until cleared.
- 0005 (`0005-sds-build-from-nimble-resolution.md`) — the artifact hooks
  reuse the same engine.
