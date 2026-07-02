# ADR 0003: Platform-target-specific build artifacts in status-desktop

## Status

Accepted

This ADR combines two platform-target-specific concerns that compose without overlap:

- **Platform sentinel ownership** (desktop↔mobile artifact staleness) — Accepted.
- **iOS libsds Nim-runtime symbol localization** (Nim-runtime symbol collision) — Superseded by an upstream fix in nim-sds `v0.2.5` (see [Part 2](#part-2-ios-libsds-nim-runtime-symbol-localization)).

## Part 1: Platform sentinel ownership

### Context

Several third-party libraries built from `vendor/` write to **shared output paths** that are reused across desktop macOS, iOS, and Android builds in the same working tree:

- `vendor/QR-Code-generator/c/` (object files and `libqrcodegen.a` in the source tree; cleaned via `make clean`)
- `vendor/nim-sds/build/` (whole directory: `libsds.*` plus nim-sds nimcache)
- `vendor/status-go/build/` (whole directory: `libstatus.*`, generated bindings, etc.)
- `nimcache/` (flat mobile nim cache at repo root plus desktop subdirs under `release/` / `debug/`)
- `bin/libnim_status_client.*` (shared nim client static/shared library output)

Switching between `make run` (desktop) and `make mobile-run` (iOS/Android) without cleaning these paths leaves stale platform-specific objects. The linker then fails (e.g. `ld: building for 'iOS', but linking in object file ... built for 'macOS'`) or the app crashes at runtime with mixed artifacts.

An earlier fix added a per-artifact sentinel inside `vendor/status-go/Makefile` (`nim-sds-platform-check`, `.sds-build-id`) for libsds only. That did not cover qrcodegen or libstatus, and duplicated platform-key logic across submodules.

#### Ownership of the status-go / nim-sds mobile build

Issue [#18377](https://github.com/status-im/status-desktop/issues/18377) (commit `0b5f1106`) moved the status-go mobile build logic out of `mobile/scripts/buildStatusGo.sh` and into the **status-go repository**. The status-go `Makefile` now owns building both `libstatus` and `libsds` (it pins `NIM_SDS_VERSION`, clones, and builds nim-sds), exposed via the `.PHONY` targets `statusgo-ios-library` / `statusgo-android-library`.

Consequently `$(STATUS_GO_LIB)` in `mobile/Makefile` must **not** re-introduce knowledge of status-go/nim-sds source files (e.g. `find`-based prerequisites): that would re-couple status-desktop to vendor internals and revert #18377. The freshness decision belongs to status-go's own (PHONY) build.

The defect we hit: `$(STATUS_GO_LIB)` was a plain file target with **no prerequisites**, so once `mobile/lib/<variant>/libstatus.a` existed, Make never re-invoked the delegated sub-make. Stale copies then linked against a freshly rebuilt `libnim_status_client`, producing duplicate Nim runtime symbols and a runtime crash.

### Decision

Implement a **single umbrella platform sentinel in status-desktop**:

1. Caller Makefiles define a `.PHONY` target `platform-cleanup` that runs `scripts/platform_pre_build_cleanup.sh` with `PLATFORM_TARGET`:
   - Root: `$(host_os)-$(QT_ARCH)` (e.g. `darwin-arm64`)
   - Mobile: `$(OS)-$(ARCH)` (e.g. `ios-arm64`, `android-arm64`)
2. Shared-artifact build targets (`$(NIMSDS_LIBFILE)`, `$(STATUSGO)`, `$(QRCODEGEN)` in root; `$(STATUS_GO_LIB)`, `$(QRCODEGEN_LIB)` in mobile) list `platform-cleanup` as an **order-only** prerequisite (`| platform-cleanup`), so cleanup runs before those targets are built without forcing them (or their dependents) to relink every time.
3. The script compares the key to `.platform-target` at the repo root. On mismatch, **delete** shared artifacts (registry above) via coarse directory-level cleanup and write the new key.
4. Remove the libsds-specific sentinel from `vendor/status-go/Makefile`. Keep the independent iOS C++ CGO fix (`CXX` / `CGO_CXXFLAGS` for libutp). The separate iOS duplicate-Nim-runtime collision is handled by [Part 2](#part-2-ios-libsds-nim-runtime-symbol-localization), not by this sentinel.
5. Make `$(STATUS_GO_LIB)` in `mobile/Makefile` depend on a `FORCE` empty target so it **always** delegates to status-go's PHONY sub-make (which owns the incremental-rebuild decision per #18377). The recipe copies `libstatus`/`libsds` into `mobile/lib` with `cmp -s … || cp`, so dependents (`stub`, `service`, the app) only relink when the output actually changed. status-desktop therefore does not track status-go/nim-sds sources.

Because the copy is refreshed on every build via FORCE + `cmp||cp`, the sentinel does **not** clean `mobile/lib/<variant>/libstatus.*` / `libsds.*`; wiping the vendor `build/` dirs is sufficient to produce fresh per-platform copies.

`clean_switch_os.sh` remains as a manual full reset for iOS↔Android; it is not replaced.

### Consequences

#### Positive

- One mechanism covers all shared vendor artifacts relevant to desktop↔mobile switching.
- Coarse directory cleanup (`vendor/*/build`, `nimcache`, etc.) avoids maintaining a growing per-file registry.
- `FORCE` delegation keeps status-desktop ignorant of status-go/nim-sds internals (honors #18377); the freshness decision stays in status-go's own build.
- `cmp -s || cp` means dependents (`stub`/`service`/app) relink only when the library content changed, despite the recipe running every build.
- The sentinel handles cross-platform contamination; FORCE handles within-platform freshness. No overlap, and `mobile/lib` copies need no explicit cleanup.
- No symlink or per-platform directory layout changes in upstream vendors (nim-sds `sds.nims` still writes to `build/`).

#### Negative

- Every mobile build invokes status-go's sub-make (a go build-cache check plus a libsds check, typically a few seconds even when nothing changed). Accepted as the cost of #18377-style delegation.
- Standalone builds of `vendor/status-go` outside status-desktop no longer auto-clean libsds on platform switch; developers must clean manually or use status-desktop's sentinel via the root/mobile Makefiles.
- Each platform switch triggers full rebuild of deleted shared artifacts (~30–70s for nim-sds + status-go), traded for correctness over incremental speed.

### Alternatives considered

| Alternative | Why rejected |
|-------------|--------------|
| Per-artifact sentinels in each Makefile | Duplicated logic; easy to miss a shared path |
| C-pure platform-scoped output dirs | Upstream nim-sds/qrcodegen bake in `build/` paths; requires build-then-move and propagating keys to shell scripts |
| C-symlink (per-platform dirs + symlink) | Same benefit as C-pure for speed, but extra failure modes (dangling symlinks, race with nim cache) for modest gain |
| `find`-based source prerequisites on `$(STATUS_GO_LIB)` | Re-couples status-desktop to status-go/nim-sds sources; reverts #18377 (the build was deliberately delegated to status-go) |
| Sentinel only (no FORCE) | Leaves the no-prerequisites file target; stale `mobile/lib` copies still block the delegated sub-make within a platform |
| Parse-time `$(shell …)` hook | Runs on every Make invocation (including `help`, `clean`, dry-run); side effects during variable assignment are not idiomatic Make |
| **Accepted: order-only `platform-cleanup` + FORCE delegation + coarse clean-on-switch** | Cleanup is a proper target in the dependency graph; sentinel for cross-platform contamination; FORCE + `cmp||cp` for within-platform freshness, with status-go owning the rebuild decision |

## Part 2: iOS libsds Nim-runtime symbol localization

> Superseded — fix landed upstream in nim-sds `v0.2.5` (see [Decision history](#decision-history)).

### Context

On iOS the final app binary statically links both:

- `libsds.a` — the nim-sds reliability layer (built by status-go's `statusgo-ios-library` → `build-libsds-ios`, see Part 1).
- `libnim_status_client.a` — the status-desktop Nim client.

Both are compiled from Nim and therefore each ship a **full copy of the Nim runtime** (`_allocSharedImpl`, `_newSeqPayload`, `_rawNewString`, `_nimAsgnStrV2`, …) exported as **global** (`T`) symbols. Diagnostics on the failing build showed `libsds.a` exporting ~20 global Nim-stdlib symbols and `libnim_status_client.a` ~21, with a large overlap; `libstatus.a`, `libMobileWebView.a`, `libStatusQ.a` export **zero** (they are not Nim or already localized).

When the linker sees the duplicate definitions it collapses them into a single copy. The surviving copy comes from `libnim_status_client` (built with a different Nim version than nim-sds), so `libsds`'s code runs against a runtime it was not compiled for. The app then crashes with **SIGSEGV at runtime** — specifically after login, when the messenger first calls into SDS (`UnwrapReceivedMessage`).

This is *not* the platform-switch / stale-artifact problem solved in Part 1 (that was a freshness bug; this is a symbol-collision bug present even on a clean build).

#### Alternatives tried and rejected

| Alternative | Why rejected |
|-------------|--------------|
| `-Wl,-load_hidden,libsds.a` in `vendor/status-go/Makefile` (CGO_LDFLAGS) and/or `mobile/wrapperApp/Status.pro` | `-load_hidden` changes symbol **visibility** but does not **remove** the global symbols from `libsds.a`. The duplicate-symbol collision happens before visibility is applied, so the wrong runtime is still picked. Verified not to fix the crash; reverted. |
| Drop `-lsds` from `Status.pro` | `libstatus.a` keeps undefined references into SDS (`U _SdsNewReliabilityManager`); `libsds.a` is genuinely required as a separate input. |

### Decision history

#### 1. Post-build localization in status-desktop (interim)

Localize `libsds.a` as a **post-build step in status-desktop**, after status-go produces it and before it is copied into `mobile/lib`. This kept the fix in our repo instead of patching upstream nim-sds or status-go while we waited for an upstream release.

`mobile/Makefile` (iOS only) ran `mobile/scripts/localize_libsds_ios.sh` on `$(NIM_SDS_SOURCE_DIR)/build/libsds.a` right after the `statusgo-ios-library` sub-make and before the `cmp -s … || cp` into `$(LIB_PATH)`.

The script exploded the archive (`ar x`), merged all objects into one relocatable object exporting **only** the public API via `xcrun ld -r -arch <arch> -exported_symbol '_Sds*'`, and repacked with `ar rcs`.

#### 2. Upstream fix in nim-sds `v0.2.5` (current)

nim-sds `v0.2.5` localizes symbols during the iOS build in `sds.nimble` (`libsdsIOS` task). status-go pins `NIM_SDS_VERSION=v0.2.5`; status-desktop no longer runs a post-build localization step.

The result is unchanged: `libsds.a` exposes only `_Sds*`; its Nim runtime is internalized, so there is exactly one global Nim runtime (from `libnim_status_client`) at final link.

### Consequences

#### Positive

- Fix lives in nim-sds where the iOS build is defined; status-desktop mobile Makefile stays a thin delegate + copy layer (honors #18377).
- Orthogonal to Part 1: the sentinel handles platform-switch staleness; symbol localization handles the Nim-runtime collision. They compose without overlap.

#### Negative

- iOS-only and macOS-toolchain-specific (`xcrun ld -r`, `-exported_symbol`) inside nim-sds. Android/desktop are unaffected.
- Couples the fix to the exact public-symbol prefix (`_Sds*`). If nim-sds renames its exported API, the exported-symbol pattern must be updated or the link will drop needed symbols.
