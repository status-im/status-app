# ADR 0003: Platform-target-specific build artifacts in status-desktop

## Status

Accepted

Two platform-target-specific concerns that compose without overlap:

- **Platform sentinel ownership** (desktop↔mobile artifact staleness) — Accepted.
- **iOS libsds Nim-runtime symbol collision** — Superseded by an upstream fix in nim-sds `v0.2.5` (see [Part 2](#part-2-ios-libsds-nim-runtime-symbol-collision)).

## Part 1: Platform sentinel ownership

### Context

Some `vendor/` libraries write to **shared output paths** reused across desktop macOS, iOS, and Android builds in the same tree (`vendor/QR-Code-generator/c/`, `vendor/nim-sds/build/`, `vendor/status-go/build/`). Switching between `make run` (desktop) and `make mobile-run` (mobile) without cleaning them leaves stale platform-specific objects, so the link fails (`ld: building for 'iOS', but linking in object file … built for 'macOS'`) or the app crashes on mixed artifacts.

Issue [#18377](https://github.com/status-im/status-desktop/issues/18377) moved the status-go/nim-sds mobile build into the **status-go repo** (`.PHONY` targets `statusgo-{ios,android}-library`, which own `NIM_SDS_VERSION` and the incremental-rebuild decision). status-desktop must therefore not re-introduce knowledge of status-go/nim-sds sources (e.g. `find`-based prerequisites), or it reverts #18377. But `$(STATUS_GO_LIB)` was a file target with **no prerequisites**: once it existed Make never re-ran the delegated sub-make, so stale copies linked against a fresh `libnim_status_client` and crashed.

### Decision

A single umbrella platform sentinel in status-desktop:

1. Caller Makefiles define a `.PHONY` target `platform-cleanup` running `scripts/platform_pre_build_cleanup.sh` with `PLATFORM_TARGET` (root: `$(host_os)-$(QT_ARCH)`; mobile: `$(OS)-$(ARCH)`).
2. Shared-artifact build targets list `platform-cleanup` as an **order-only** prerequisite (`| platform-cleanup`), so cleanup runs before them without forcing relinks.
3. The script compares the key to `.platform-target`; on mismatch it deletes the shared paths in [Maintenance](#maintenance) (coarse, directory-level) and writes the new key.
4. `$(STATUS_GO_LIB)` in `mobile/Makefile` depends on a `FORCE` target so it **always** delegates to status-go's sub-make, then copies into `mobile/lib` with `cmp -s … || cp` — dependents relink only when the library content actually changed.

The libsds-specific sentinel in `vendor/status-go/Makefile` is removed. `clean_switch_os.sh` remains as a manual full reset.

### Consequences

- The sentinel handles cross-platform contamination; `FORCE` + `cmp||cp` handles within-platform freshness with status-go owning the rebuild decision (honors #18377). No overlap; `mobile/lib` copies need no explicit cleanup.
- Every mobile build invokes status-go's sub-make (a few seconds even when nothing changed), and each platform switch triggers a full rebuild of the deleted artifacts (~30–70s). Traded for correctness.
- `scripts/platform_pre_build_cleanup.sh` is a manual registry of shared vendor paths (see [Maintenance](#maintenance)); accepted over per-artifact sentinels scattered across Makefiles.

### Maintenance

`scripts/platform_pre_build_cleanup.sh` must stay aligned with vendor dependencies that write platform-specific artifacts into **shared paths** used by both desktop and mobile builds.

Currently cleaned on platform switch:

| Path | Action |
|------|--------|
| `vendor/QR-Code-generator/c/` | `make clean` (artifacts in the source tree, not `build/`) |
| `vendor/nim-sds/build/` | `rm -rf` |
| `vendor/status-go/build/` | `rm -rf` (whole tree) |

When adding a new shared-artifact vendor dependency: add `| platform-cleanup` on its build target, add a cleanup step to the script (prefer wiping a whole `build/` dir), and update the table above. Vendors with separate desktop/mobile output dirs (DOtherSide, status-keycard-qt) do not belong here.

### Alternatives considered

| Alternative | Why rejected |
|-------------|--------------|
| Per-artifact sentinels in each Makefile | Duplicated logic; easy to miss a shared path |
| Platform-scoped output dirs (build-then-move or symlink) | Upstream vendors bake in `build/` paths; needs key propagation into shell scripts, extra failure modes |
| `find`-based source prerequisites on `$(STATUS_GO_LIB)` | Re-couples to status-go/nim-sds sources; reverts #18377 |
| Sentinel only (no FORCE) | Stale `mobile/lib` copies still block the delegated sub-make within a platform |
| Parse-time `$(shell …)` hook | Runs on every Make invocation; side effects during variable assignment are not idiomatic |

## Part 2: iOS libsds Nim-runtime symbol collision

> Superseded — fixed upstream in nim-sds `v0.2.5`.

On iOS the app statically linked both `libsds.a` and `libnim_status_client.a`, each shipping a full copy of the Nim runtime as **global** symbols. The linker collapsed the duplicates onto `libnim_status_client`'s copy (a different Nim version), so libsds ran against a runtime it wasn't compiled for and crashed with SIGSEGV after login (first SDS call). `-load_hidden` didn't help (changes visibility, not the duplicate symbols); dropping `-lsds` broke undefined refs from libstatus.

Interim fix was a post-build localization step in status-desktop (`ar x` → merge into one object exporting only `_Sds*` via `xcrun ld -r -exported_symbol` → `ar rcs`). nim-sds `v0.2.5` now does this in `sds.nimble` (`libsdsIOS`), so status-desktop carries no localization code. Orthogonal to Part 1 (freshness vs symbol collision). Caveat: the fix is coupled to the `_Sds*` public-symbol prefix — renaming the exported API requires updating the pattern.
