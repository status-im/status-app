# Package

version       = "0.1.0"
author        = "Status Research & Development GmbH"
description   = "Desktop client for the Status Network built with Nim and Qt"
license       = "MPL2"
srcDir        = "src"
# No `bin`: make builds the client; nimble owns dependencies only.

requires "nim == 2.2.10"  # 2.2.4-2.2.8 cannot compile wallet_section/all_tokens

requires "https://github.com/status-im/nim-chronicles.git#e7f87336d2fa47b7752b42f0be4cabd5663a5e5c"  # chronicles
requires "https://github.com/status-im/nim-chronos.git#31ddf9be6560072f83aeb25933c3132d4ecd638e"  # chronos
requires "https://github.com/status-im/nim-confutils.git#36f3115ca350f40841ac0eecc7dfa5fe7790c864"  # confutils
requires "https://github.com/status-im/nim-stew.git#784aba67a3217ff1fe810b8070857d21189945bf"  # stew
requires "https://github.com/status-im/nim-stint.git#c3e76a01580ae2ac0e62fbd04040722f8f22b84d"  # stint
requires "https://github.com/status-im/nim-json-serialization.git#43e12f9693f52236786549b09d0306672c69315d"  # json_serialization
requires "https://github.com/status-im/nim-web3.git#aa40059eb54f516031025aefccae5c221c0a27a9"  # web3
requires "https://github.com/status-im/nim-eth.git#9a9b0b2cc998cacbfc9e335e49e56eb4d247bf7f"  # eth
requires "https://github.com/arnetheduck/nim-result.git#06deae1c81fd27b6c94bbc7cd0e619b6905d49da"  # results
requires "https://github.com/nitely/nim-regex.git#2c41f0b2fee9fe78cf22f029bc854a77ac2e9768"  # regex
requires "https://github.com/cheatfate/nimcrypto.git#423ea4fed8de6f4544b7e3b30d868f527ed3b947"  # nimcrypto
requires "https://github.com/status-im/uuids.git#42052ba362a9cd4685463edb3781beeb9b8e547e"  # uuids, status-im fork, same revision
requires "https://github.com/status-im/nim-keycard-go.git#de7eec7d550161b8fac3d5f19b8c752d5e6d689f"  # keycard_go
requires "https://github.com/status-im/nim-taskpools.git#4acdc6ef005a93dba09f902ed75197548cf7b451"  # taskpools
requires "https://github.com/status-im/status-go.git#56ae4167518a2e1fcfcb5aa75ffac367056c3dc0"  # statusgo
# isaac by version, not revision: a revision pin leaves later `nimble setup` on the same store naming a missing directory.
requires "isaac == 0.2.0"  # isaac, transitive (uuids)
requires "https://github.com/status-im/nim-bearssl.git#9a4eed052abbded2d94feaf3f5bbd95a30ec4671"  # bearssl, transitive (chronos)
requires "https://github.com/status-im/nim-secp256k1.git#d8f1288b7c72f00be5fc2c5ea72bf5cae1eafb15"  # secp256k1, transitive (eth)
requires "https://github.com/status-im/nim-metrics.git#a1296caf3ebb5f30f51a5feae7749a30df2824c2"  # metrics, transitive (eth)
requires "https://github.com/status-im/nim-json-rpc.git#331fbabdb018cf858ff944cd79c4b1737dd3a937"  # json_rpc, transitive (web3)
# websock is not pinned: json_rpc at this revision requires `websock < 0.4.0`.
requires "https://github.com/status-im/nim-http-utils.git#f142cb2e8bd812dd002a6493b6082827bb248592"  # httputils, transitive (chronos)
requires "https://github.com/status-im/nim-zlib.git#c9e64574438e69f3dd9b64da048f9fffc89e2809"  # zlib, transitive (websock)
requires "https://github.com/status-im/nim-serialization.git#1790d8a931fce125d6722f7ee8432ee8c054d297"  # serialization, transitive (json_serialization)
requires "https://github.com/vacp2p/nim-intops.git#d30bd41f7492a21e4e0baeafac493978a010568f"  # intops, transitive (stint)
requires "https://github.com/status-im/nim-faststreams.git#50889cd16ec8771106cdd0eeea460039e8571e06"  # faststreams, transitive (serialization)
requires "https://github.com/nitely/nim-unicodedb.git#8938e71cdb3332b8a16eb27a6984c8565ea4643e"  # unicodedb, transitive (regex)
requires "https://github.com/seaqt/nim-seaqt.git#7d40abd7b493036b4ede5b111fc4260237504796"  # seaqt (branch qt-6.8)
requires "https://github.com/seaqt/nimqml-seaqt.git#fa084a8d9bcf00c9ed4c2adf857793fcc059357f"  # nimqml
requires "https://github.com/status-im/prl-to-pc.git#03a8a91707db7d9257d8617453fefb58fe848904"  # prl_to_pc
