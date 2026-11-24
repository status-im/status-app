# ADR-0009: Nim packages are resolved by nimble, Nim libraries are built by status-go with plain `nim c`

## Status
- **Accepted**
- **Date**: 2026-11-24

## Context and Problem Statement

The app links several Nim libraries, directly or through status-go: nim-sds (libsds), nim-token-lists (libtkl) and, later, logos-delivery (liblogosdelivery). The app's own Nim code was built with nimbus-build-system and 35 package submodules. status-go cloned nim-sds next to itself and ran nim-sds's Makefile, and libtkl and liblogosdelivery each had their own build scripts. As a result, every library had its own compiler, its own dependency versions and its own flags: libsds used refc, while libtkl used ORC.

Every separate Nim compile produces its own Nim runtime, whether it is packaged as a static or a shared library. When two runtimes end up in one image with global symbols, the linker merges them. On iOS this made libsds run against the app's runtime and crash after login ([ADR 0003, part 2](0003-platform-sentinel-ownership.md#part-2-ios-libsds-nim-runtime-symbol-collision), status-im/status-go#8011).

Moving from nimbus-build-system to nimble (#19907) was the point at which three questions had to be settled: who resolves the Nim packages, who builds each library, and how the resulting runtimes coexist in one process.

## Decision

**The app is the nimble root and owns the resolution.**
- `nim_status_client.nimble` and `nimble.lock` (43 entries) replace nimbus-build-system and the Nim package submodules.
- The manifest pins the compiler (`nim == 2.2.10`).
- When the manifest or the lock changes, `makefiles/nimble.mk` runs `nimble setup --localdeps` (nimble >= 0.26.2). Make then builds with the Nim that setup installed in `nimbledeps/`.
- The resulting `nimble.paths` is the resolution that every Nim build uses: the app, the tests, Storybook and status-go.

**status-go stays a git submodule, outside the app's nimble graph.**
- nimble 0.26.2 crashes when a `file://` requirement drifts from the lock, and any submodule commit drifts, including a Go-only one.
- Requirements pulled in with `include` are ignored.
- So the app requires the Nim packages that status-go links (nim-sds and nim-token-lists, plus chronos) directly, with the same lines as `status_go.nimble`.

**`status_go.nimble` is the pin file for the libraries status-go links.**
- It pins the Nim compiler, nim-sds, nim-token-lists, chronos, logos-delivery and nim-leopard. Leopard comes first, because nimble keeps the first pin it sees.
- status-go has no `nimble.lock`. Standalone, everything else floats. Inside the app, the app's lock decides what ships.
- `scripts/check_nim_pins.sh` holds the other copies to it:
  - in lint: the Dockerfile's Nim version, the Nix libtkl version, the `flake.nix` revisions and `go.mod`'s tkl wrapper;
  - at build time: the nim-sds and nim-token-lists revisions in the resolution status-go is handed.
- A library bump therefore lands in status-go first, then in the app's manifest and lock.

**A library ships no build tasks. status-go compiles its entry module with plain `nim c`.**
- Each library's contract has three parts: an entry module, a public header and a C API prefix. The library's `config.nims`, next to its entry, holds the library's defaults, and the caller's flags win.
- The libraries and their contracts:
  - nim-sds: `library/libsds.nim`, `libsds.h`, prefix `sds_`.
  - nim-token-lists: `abi/libtkl.nim`, `abi/tkl.h`, prefix `tkl_`.
  - logos-delivery: `library/liblogosdelivery.nim`, `liblogosdelivery.h`, prefix `logosdelivery_`.
- The library side of this is recorded in logos-delivery's ADR "Let callers build liblogosdelivery with plain `nim c`".
- status-go's `nim.mk` is the caller. Its inputs are:
  - `NIM` and `NIMBLE_ROOT`;
  - the target as high-level values: `ARCH`, `ANDROID_API`, `ANDROID_NDK_ROOT`, `IPHONE_SDK`, `IOS_TARGET`;
  - `NIM_PARAMS`.

  Every input has a default, so status-go still builds standalone.
- `nim.mk` runs `nim c --skipParentCfg` with the `nimble.paths` entries as `--path` flags, so the app's `config.nims` does not leak into library builds. It reads a package's directory from `nimble.paths`, not from `nimble path`, which lists every installed version.

**The app owns the build policy.**
- `makefiles/nim-libs.mk` passes `NIM`, `NIMBLE_ROOT` and `NIM_PARAMS` to status-go's make. `NIM_PARAMS` replaces status-go's defaults, which exist only for standalone builds.
- The policy is `--mm:orc -d:useMalloc --threads:on`, plus a per-target part:
  - desktop: `--opt:speed` and TRACE logs;
  - mobile: `--opt:size -d:release` and ERROR logs.
- Every library is therefore built from the app's resolution, with the app's compiler and one policy. `useMalloc` and threads match across images by construction, which a cross-image `free` and cross-thread callbacks need. libsds moved from refc to ORC with this change.

**Each library keeps its own Nim runtime. Whoever links a static one seals it.**
- How each library is linked:
  - libsds is a shared library on desktop and Android. On iOS it is a static archive, sealed to `sds_`.
  - libtkl is static, sealed to `tkl_` and linked into libstatus.
  - liblogosdelivery is built and sealed to `logosdelivery_*`, with Leopard-RS inside and without RLN. It is not linked yet, and the app does not require logos-delivery.
- `scripts/seal_nim_lib.sh` in status-go seals the objects of a fresh nimcache compiled with `--noLinking`:
  - Mach-O: `ld -r` with the exported names listed.
  - ELF and COFF: `ld -r` plus `objcopy --keep-global-symbol`, with hidden symbols made local and unique-binding symbols rejected.

We accept these costs:
- A library change needs a pin in its own repository, then status-go, then the app's manifest and lock.
- Several Nim runtimes share each process: libsds, libtkl inside libstatus, and the client's own. This costs size and threads, and sealing has to keep them apart.
- Pins are copied between `status_go.nimble` and the app's manifest. Only the nim-sds and nim-token-lists revisions are checked against the app's resolution.

## Alternatives Considered

- **status-go as a nimble requirement pinned by sha, next to the submodule.** This means two pins of one thing, kept equal by a check. Rejected in favour of a single pin per library.
- **A `file://` requirement on the submodule.** It gives one source of truth, but nimble 0.26.2 crashes on any submodule drift, so every status-go bump would re-resolve the whole graph.
- **status-go as a nimble-only dependency, without the submodule.** This is nimble's intended model and has one pin. However, the Go build would run from a read-only installed copy, 37 files in the app reference `vendor/status-go`, and local development would need `nimble develop`, which nimble 0.26 ignores when a lock is present. This is the planned next step once those problems are solved.
- **status-go owns the library flags**, the first draft of this decision. Reversed: the app is what ships, and its own runtime is what the flags must match.
- **A policy per library, starting at parity with today** (refc for libsds). Runtime behaviour would stay unchanged, but this needs a variable per library, and the libraries have to move to the app's policy anyway.
- **The app passes fully spelled target flags.** status-go needs them for its standalone builds anyway, so the toolchain knowledge would live in two places.
- **A `nimble.lock` in status-go.** It would be a second graph to keep equal to the app's. status-go's CI proves that the pins build and link, and the app's CI proves the set that ships.
- **Drop the app lock and pin everything with `==`.** The libraries' transitive requirements are ranges, so builds would float, and the lock's checksums would be lost.
- **Each library builds and seals itself**, as nim-sds did on iOS. This duplicates one recipe in every library and puts target knowledge in each of them. Only the linker of the final image knows what shares it.
- **One Nim runtime per process**, with every Nim library compiled from source into the app. This gives smaller binaries, fewer threads and native calls between Nim code. Rejected for now: the app will integrate Logos Core modules, which ship as separately built images. A spike exists, and nothing has landed.

## More Information

- Implementation:
  - status-app: #22822, #22489, #23053.
  - status-go: #7757, #7877, #8042, #8045, #8092.
  - nim-sds: logos-messaging/nim-sds#115.
  - nim-token-lists: status-im/nim-token-lists#26 (v0.2.0).
  - logos-delivery: logos-messaging/logos-delivery#4744.
  - nim-leopard: logos-storage/nim-leopard#34.
- Library side: [logos-delivery ADR-0001](https://github.com/logos-messaging/logos-delivery/blob/master/docs/decisions/0001-let-callers-build-liblogosdelivery-with-plain-nim-c.md).
- Supersedes the sealing note in [ADR 0003, part 2](0003-platform-sentinel-ownership.md#part-2-ios-libsds-nim-runtime-symbol-collision): nim-sds no longer seals libsds, status-go does.
- Known gaps as of 2026-11-24:
  - status-go pins `nim == 2.2.12` (status-im/status-go#8089), while the app pins 2.2.10 and passes that compiler to status-go. The pin check does not cover the Nim version, chronos, logos-delivery or nim-leopard. logos-delivery requires Nim >= 2.2.12, so this matters as soon as liblogosdelivery is linked.
  - Nothing checks the sds-go-bindings ↔ nim-sds ABI pairing.
  - Local overrides of a Nim package are not settled. `nimble.develop` is gitignored, but make regenerates `nimble.paths` only when the manifest or the lock changes.
  - status-go's Nix package builds libsds and libtkl from flake inputs, not through nimble. The pin check holds it to the same revisions, but not to the same flags or sealing.
- Revisit:
  - when nimble handles a drifting `file://` requirement and `nimble develop` under a lock, which would allow status-go to be a nimble-only dependency;
  - when Logos Core offers a way to compile Nim modules into one host runtime.
