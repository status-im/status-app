# Package

version       = "0.1.0"
author        = "Status Research & Development GmbH"
description   = "Desktop client for the Status Network built with Nim and Qt"
license       = "MPL2"
srcDir        = "src"
bin           = @["nim_status_client"]
skipExt       = @["nim"]

# Nim version pin + app dependencies, resolved by `nimble setup` into the
# out-of-tree store at ~/.cache/status-desktop-nimbledeps (APP_NIMBLE_DIR;
# run automatically by the Makefile). Frozen in nimble.lock.
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
# uuids: upstream-PR head = 0.1.12 (42052ba) + one commit: modern-format
# manifest with isaac pinned by revision. Upstream pragmagic/{uuids,isaac}
# ship INI-style ([Package]) manifests, and nimble 0.22.3's dependency
# validation extracts an EMPTY version from an INI manifest on a fresh clone
# — uuids' former `isaac >= 0.1.3` range then fails ("wanted >= 0.1.3 got .")
# and uuids is dropped from the graph, hard-failing every clean-store
# lock-mode solve. isaac stays unlisted here: the pinned uuids manifest pins
# it (pragmagic/isaac#5bd05be4 = the pragmagic/isaac#4 head; v0.1.3 content,
# modern manifest). PR-only commits resolve fine (verified 2026-07-07); bump
# both pins to the merge commits when the pragmagic PRs land.
requires "https://github.com/pragmagic/uuids.git#f89d1f5ce7901bb3f0dd637019d3b8fe58219d5c"  # uuids
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
