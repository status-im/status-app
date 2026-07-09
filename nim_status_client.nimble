# Package

version       = "0.1.0"
author        = "Status Research & Development GmbH"
description   = "Desktop client for the Status Network built with Nim and Qt"
license       = "MPL2"
srcDir        = "src"
bin           = @["nim_status_client"]
binDir        = "bin"  # nimble's bin compile lands exactly where make's does
skipExt       = @["nim"]

# Nim version pin + app dependencies, resolved by `nimble setup` into
# nimble's default store (~/.nimble; run automatically by the Makefile and
# by nimble build/run themselves). Frozen in nimble.lock.
requires "nim == 2.2.4"

requires "https://github.com/status-im/nim-chronicles.git#e7f87336d2fa47b7752b42f0be4cabd5663a5e5c"  # chronicles
requires "https://github.com/status-im/nim-chronos.git#31ddf9be6560072f83aeb25933c3132d4ecd638e"  # chronos
requires "https://github.com/status-im/nim-stew.git#784aba67a3217ff1fe810b8070857d21189945bf"  # stew
requires "https://github.com/status-im/nim-stint.git#c3e76a01580ae2ac0e62fbd04040722f8f22b84d"  # stint
requires "https://github.com/status-im/nim-json-serialization.git#43e12f9693f52236786549b09d0306672c69315d"  # json_serialization
requires "https://github.com/status-im/nim-serialization.git#1790d8a931fce125d6722f7ee8432ee8c054d297"  # serialization
requires "https://github.com/status-im/nim-faststreams.git#50889cd16ec8771106cdd0eeea460039e8571e06"  # faststreams
# json_rpc >= 0.6.1: 0.6.0 caps websock < 0.4.0, while libp2p 2.x (pinned in
# the workspace nim-sds; enters via status-go) needs websock >= 0.4.0 — 0.6.1
# lifts the cap.
requires "https://github.com/status-im/nim-json-rpc.git#6f1fff8ba685c9192fab153a9d66484ad9066e78"  # json_rpc v0.6.1
requires "https://github.com/status-im/nim-web3.git#aa40059eb54f516031025aefccae5c221c0a27a9"  # web3
requires "https://github.com/status-im/nim-eth.git#9a9b0b2cc998cacbfc9e335e49e56eb4d247bf7f"  # eth
requires "https://github.com/status-im/nim-secp256k1.git#d8f1288b7c72f00be5fc2c5ea72bf5cae1eafb15"  # secp256k1
requires "https://github.com/status-im/nim-bearssl.git#9a4eed052abbded2d94feaf3f5bbd95a30ec4671"  # bearssl
requires "https://github.com/status-im/nim-metrics.git#a1296caf3ebb5f30f51a5feae7749a30df2824c2"  # metrics
requires "https://github.com/status-im/nim-http-utils.git#f142cb2e8bd812dd002a6493b6082827bb248592"  # httputils
requires "https://github.com/status-im/nim-zlib.git#c9e64574438e69f3dd9b64da048f9fffc89e2809"  # zlib
requires "https://github.com/status-im/nim-taskpools.git#4acdc6ef005a93dba09f902ed75197548cf7b451"  # taskpools
requires "https://github.com/arnetheduck/nim-result.git#06deae1c81fd27b6c94bbc7cd0e619b6905d49da"  # results
requires "https://github.com/nitely/nim-regex.git#2c41f0b2fee9fe78cf22f029bc854a77ac2e9768"  # regex
requires "https://github.com/nitely/nim-unicodedb.git#8938e71cdb3332b8a16eb27a6984c8565ea4643e"  # unicodedb
requires "https://github.com/vacp2p/nim-intops.git#d30bd41f7492a21e4e0baeafac493978a010568f"  # intops
requires "https://github.com/cheatfate/nimcrypto.git#423ea4fed8de6f4544b7e3b30d868f527ed3b947"  # nimcrypto
# uuids: upstream-PR head (pragmagic/uuids#15) = 0.1.12 (42052ba) + one
# commit: modern-format manifest with isaac pinned by revision. Upstream
# uuids still ships an INI-style ([Package]) manifest at its tags, and
# nimble 0.22.3's dependency validation extracts an EMPTY version from an
# INI manifest on a fresh clone — uuids' former `isaac >= 0.1.3` range then
# fails ("wanted >= 0.1.3 got .") and uuids is dropped from the graph,
# hard-failing every clean-store lock-mode solve. isaac stays unlisted
# here: the pinned uuids manifest pins it at pragmagic/isaac master
# ca0a1e25 (= merged isaac#4, 2026-07-09; modern manifest). Bump this pin
# to the merge commit when uuids#15 lands.
requires "https://github.com/pragmagic/uuids.git#1a8111cc2b0e82867d19d584012e510560446d97"  # uuids
# status-go is a nimble package (the status_go wrapper ships inside it, so the
# former separate nim-status-go wrapper requirement is gone); its manifest
# carries the nim-sds pin, which lands in this graph transitively. INTERIM
# branch pin (nimble-phase1-pin on status-im/status-go) until the nimble
# packaging work merges upstream — bump by amending the #hash. Default mode
# has no vendor/status-go checkout: the store copy is built via the
# .statusgo-build scratch (issue 0010), and `nim develop status.nims statusgo`
# materializes an editable checkout (issue 0009, ADR 0004 overlay — nimble
# 0.22.3 develop links cannot satisfy URL#hash requires).
requires "https://github.com/status-im/status-go.git#d9281bce98803c84c8c414a3b4a64103b629206a"
requires "https://github.com/status-im/nim-keycard-go.git#c8a39e8d4a8abd1bba2fb3d8fe32f8a11cbbd75a"  # keycard_go
# The seaqt pair (issue 0012): generated Qt bindings (package `seaqt`, repo
# nim-seaqt) + the NimQml layer on top (package `nimqml`, repo nimqml-seaqt).
# Pure-source packages: the generated C++ shims compile via {.compile.} into
# the client's own nimcache, so the read-only store copies are consumed
# directly (no sub-build, no scratch engine). The seaqt pin is the tip of
# upstream branch `smo-6.4` (the Status-specific generation; the repo's tag
# qt-6.4-seaqt-gen-5bc1bc58… points exactly at it) — NOT branch `qt-6.4`,
# which is force-pushed and its head drops the QVariantConstPointer compat
# shim that seaqt_compat/ relies on. The nimqml pin is an ancestor of its
# upstream master. Any pin bump is a deliberate separate decision (API-churn
# risk; see the 0012 grill record). `nim develop status.nims seaqt|nimqml`
# materializes editable checkouts (ADR 0004 overlay).
requires "https://github.com/seaqt/nim-seaqt.git#2d95808bdd9f6dd2c212b69a57af4618da241d37"  # seaqt (branch smo-6.4)
requires "https://github.com/seaqt/nimqml-seaqt.git#c5e5831ae7d71e09f7061bc7735a8f3e1adc8fb3"  # nimqml
# prl-to-pc (issues 0014, 0015): qt_pkgconfig.nims (the executed consumer
# interface: kit derivation, the System/Generated probe, tool building and
# .pc generation) + the committed relocatable Qt .pc trees + the
# wrapper/generator sources — the Qt-flag discovery seaqt's compile-time
# `gorge("pkg-config …")` depends on. Consumed as package-root FILES (the
# driver runs `nim e <root>/qt_pkgconfig.nims <cmd>`; the root Makefile
# still includes <root>/qt-pkgconfig.mk for the interim mobile/nim-test make
# legs; nothing nim-imports its modules), so its manifest declares neither
# bin nor srcDir: either one makes nimble strip the store copy down to
# sources. The tools build into the repo-local .prl-to-pc-build/ scratch;
# the store copy is never written to. `nim develop status.nims prl-to-pc`
# for an editable checkout (ADR 0004 overlay).
#
# Pinned to the annotated tag `v0.3.0` (peels to 4a31fc06). Tag pins resolve
# on nimble 0.22.3 exactly like a `#sha` special version, and additionally
# carry the manifest's semantic version: the store entry's nimblemeta.json
# records `specialVersions ['0.3.0', '#v0.3.0']`. The pkgcache key embeds the
# ref, so bumping the tag mints a fresh clone — the pkgcache-staleness wall
# (walls doc) does not bite here.
requires "https://github.com/status-im/prl-to-pc.git#v0.3.0"  # prl_to_pc

include "status.nims"

# nimble-native front door (issue 0013). nimble's bin compile only compiles
# src/nim_status_client.nim (config.nims provides the full flag set); every
# artifact the client links or loads — StatusQ, libstatus + libsds, the
# keycard pair, qrcodegen, DOtherSide, resources.rcc, translations, the Qt
# pkg-config wrapper — is built by this hook through the same stamp-gated
# engine `nim app status.nims` drives. A no-op re-run costs seconds; the
# hook fires for both `nimble build` and `nimble run` (run builds the root
# binary through the same path). Kit-env problems fail here, fast, with the
# driver's exact-variable messages.
#
# STATUS_SKIP_BUILD_ARTIFACTS=1 skips the artifact build as a SUCCESSFUL
# no-op (source-only workflows): `return false` is nimble's hook-cancel,
# which hard-fails the whole action (0.22.3 wall — unusable as a skip).
before build:
  if getEnv("STATUS_SKIP_BUILD_ARTIFACTS") == "1":
    echo "status: skipping the artifact build (STATUS_SKIP_BUILD_ARTIFACTS=1)"
  else:
    try:
      exec "nim buildArtifacts status.nims"
    except OSError:
      echo "status: artifact build failed — fix the error above, then re-run."
      return false

after build:
  # make's client recipe runs the same fixups post-link: the Go-built
  # libstatus carries a bare install name, so the reference must be
  # rewritten to @rpath for the baked rpaths to resolve it. Idempotent —
  # a rewritten binary has no bare reference left to change.
  when defined(macosx):
    exec "install_name_tool -change libstatus.dylib @rpath/libstatus.dylib bin/nim_status_client"
    exec "install_name_tool -change libstatus-keycard-qt.dylib @rpath/libstatus-keycard-qt.dylib bin/nim_status_client"