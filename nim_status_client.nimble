# Package

version       = "0.1.0"
author        = "Status Research & Development GmbH"
description   = "Desktop client for the Status Network built with Nim and Qt"
license       = "MPL2"
srcDir        = "src"
bin           = @["nim_status_client"]
binDir        = "bin"  # where every front door puts the client binary
skipExt       = @["nim"]

# Nim pin + app dependencies, resolved by `nimble setup` into nimble's default
# store (~/.nimble) and frozen in nimble.lock.
#
# nim 2.2.10: 2.2.4-2.2.8 fail to instantiate a closure returning `var seq`
# from inside a Table value (wallet_section/all_tokens).
#
# The nimble floor: 0.24.x is the first release that solves this graph from a
# clean store (0.22.x fails with or without a system nim, and only gets there
# against a store that is already warm). BUILDING.md has the download line.
const RequiredNimble = "0.24.1"

# A Nim 2.2.10 already on PATH is fine: nimble reuses it instead of
# materialising the store entry, and it is the same official tarball nimble
# would download. Any other Nim on PATH is fine too — nimble then materialises
# the pin, and the build uses that.
requires "nim == 2.2.10"

requires "https://github.com/status-im/nim-chronicles.git#e7f87336d2fa47b7752b42f0be4cabd5663a5e5c"  # chronicles
requires "https://github.com/status-im/nim-chronos.git#31ddf9be6560072f83aeb25933c3132d4ecd638e"  # chronos
requires "https://github.com/status-im/nim-stew.git#784aba67a3217ff1fe810b8070857d21189945bf"  # stew
requires "https://github.com/status-im/nim-stint.git#c3e76a01580ae2ac0e62fbd04040722f8f22b84d"  # stint
requires "https://github.com/status-im/nim-json-serialization.git#43e12f9693f52236786549b09d0306672c69315d"  # json_serialization
requires "https://github.com/status-im/nim-serialization.git#1790d8a931fce125d6722f7ee8432ee8c054d297"  # serialization
requires "https://github.com/status-im/nim-faststreams.git#50889cd16ec8771106cdd0eeea460039e8571e06"  # faststreams
# json_rpc must be >= 0.6.1: 0.6.0 caps websock < 0.4.0, while the libp2p 2.x
# that enters via status-go's nim-sds needs websock >= 0.4.0.
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
requires "https://github.com/vacp2p/nim-boringssl.git#bf0272b328ae0c995e0fccb3b323b4e2042bfa0b"  # boringssl v0.0.12 (lsquic needs >= 0.0.11; pinned so the lock does not drift)
# uuids: the head of upstream PR pragmagic/uuids#15 — 0.1.12 plus a
# modern-format manifest that pins isaac by revision. A tagged uuids cannot be
# used: nimble 0.22.3 extracts an empty version from its INI-style manifest on
# a fresh clone, uuids' `isaac >= 0.1.3` range then fails and uuids drops out
# of the graph, failing every clean-store solve. isaac stays unlisted here
# because the pinned uuids manifest pins it. Bump to the merge commit when
# uuids#15 lands.
requires "https://github.com/pragmagic/uuids.git#1a8111cc2b0e82867d19d584012e510560446d97"  # uuids
# status-go, a nimble package that ships the status_go wrapper and carries the
# nim-sds pin transitively. Interim pin: the head of branch nimble-phase1-pin-2
# (the nimble packaging commits on top of develop), which carries the committed
# generated Go sources, the -ldflags build values and STATUS_GO_BUILD_DIR;
# bump by amending the #hash until the packaging merges upstream. Default mode
# has no vendor/status-go checkout — the read-only store copy is built in place
# with every artifact under .statusgo-build, and `nim develop status.nims
# statusgo` materializes an editable one (ADR 0007: nimble 0.22.3 develop links
# cannot satisfy URL#hash requires).
requires "https://github.com/status-im/status-go.git#e0ea415b18c747c99f7d284c6a0a7233cf68d17c"
requires "https://github.com/status-im/nim-keycard-go.git#de7eec7d550161b8fac3d5f19b8c752d5e6d689f"  # keycard_go
# The seaqt pair: generated Qt bindings (`seaqt`, the head of upstream branch
# qt-6.8) and the NimQml layer on top (`nimqml`). Pure-source packages — the
# generated C++ shims compile via {.compile.} into the client's own nimcache —
# so the read-only store copies are consumed directly. seaqt_compat/ provides
# the QVariantConstPointer shim the generated code includes.
# HAZARD: seaqt's per-Qt-version generation branches are orphans that get
# force-pushed, so a hash pin can become unreachable when the branch is
# regenerated; an upstream tag would be the fix.
requires "https://github.com/seaqt/nim-seaqt.git#7d40abd7b493036b4ede5b111fc4260237504796"  # seaqt (branch qt-6.8)
requires "https://github.com/seaqt/nimqml-seaqt.git#fa084a8d9bcf00c9ed4c2adf857793fcc059357f"  # nimqml
# prl-to-pc, the head of main: qt_pkgconfig.nims (kit derivation, the
# System/Generated probe, tool building and .pc generation), the committed
# relocatable Qt .pc trees and the wrapper/generator sources — the Qt-flag
# discovery seaqt's compile-time `gorge("pkg-config …")` depends on. Consumed
# as package-root FILES (the driver runs `nim e <root>/qt_pkgconfig.nims
# <cmd>`, the root Makefile includes <root>/qt-pkgconfig.mk; nothing
# nim-imports its modules), so its manifest declares neither bin nor srcDir:
# either one makes nimble strip the store copy down to sources. The tools build
# into the repo-local .prl-to-pc-build/ scratch, never into the store copy.
requires "https://github.com/status-im/prl-to-pc.git#03a8a91707db7d9257d8617453fefb58fe848904"  # prl_to_pc
