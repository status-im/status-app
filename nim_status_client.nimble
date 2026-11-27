# Package

version       = "0.1.0"
author        = "Status Research & Development GmbH"
description   = "Desktop client for the Status Network built with Nim and Qt"
license       = "MPL2"
srcDir        = "src"
# No `bin`: make builds the client; nimble owns the Nim packages only.

requires "nim == 2.2.12"  # 2.2.4-2.2.8 cannot compile wallet_section/all_tokens

# The Nim libraries status-go links. These lines must match
# vendor/status-go/status_go.nimble.
requires "https://github.com/logos-messaging/nim-sds#8f7fee08f0256c1788089e756182c8be0a621930"
requires "https://github.com/status-im/nim-token-lists#4df3308a32b0f3da18ef0d37d26fa9f1195f8b9e"
requires "https://github.com/logos-storage/nim-leopard#3a24aa1f4b7ce227e8d30c51357ae241cf6b478d"
requires "https://github.com/logos-messaging/logos-delivery#b3bcd23b56db43400a26d1c740bd6855c7ff9c04"
requires "chronos#0de7b335d0ad5557ad5ba71a4b7662f7b201750e"

requires "https://github.com/status-im/nim-chronicles.git#45c823b8af409f82fa35fd5e1f6a7c9a06fe3137"  # chronicles
requires "https://github.com/status-im/nim-confutils.git#ca2b17188659bb9e53419a2cdf192c0f26f9edc8"  # confutils
requires "https://github.com/status-im/nim-stew.git#5e9c0503e15c42c118f84dc167cb6bedffe8abc7"  # stew
requires "https://github.com/status-im/nim-stint.git#273fcdfa8dce4ceb975b383ffafe5e79e82766e2"  # stint
requires "https://github.com/status-im/nim-json-serialization#5bd1d25bf33ad63093dfd949435bc92d6d722a75"  # json_serialization
requires "https://github.com/status-im/nim-web3#cdfe5601d2812a58e54faf53ee634452d01e5918"  # web3
requires "https://github.com/status-im/nim-eth.git#d9135e6c3c5d6d819afdfb566aa8d958756b73a8"  # eth
requires "https://github.com/arnetheduck/nim-result.git#df8113dda4c2d74d460a8fa98252b0b771bf1f27"  # results
requires "https://github.com/nitely/nim-regex.git#a0f1df6a6512340df9ababe59f55140c94a2200f"  # regex
requires "https://github.com/cheatfate/nimcrypto.git#b3dbc9c4d08e58c5b7bfad6dc7ef2ee52f2f4c08"  # nimcrypto
requires "https://github.com/pragmagic/uuids.git#42052ba362a9cd4685463edb3781beeb9b8e547e"  # uuids
requires "https://github.com/status-im/nim-keycard-go.git#de7eec7d550161b8fac3d5f19b8c752d5e6d689f"  # keycard_go
requires "https://github.com/status-im/nim-taskpools.git#cc0ea81d10c8ef901fd58e94598004f718d6d53a"  # taskpools
requires "https://github.com/seaqt/nim-seaqt.git#7d40abd7b493036b4ede5b111fc4260237504796"  # seaqt (branch qt-6.8)
requires "https://github.com/seaqt/nimqml-seaqt.git#1b0050b8d49623296f9982845cabf71ec70cb2a0"  # nimqml
requires "https://github.com/status-im/nim-qtcamera#01fcedd967abc35d5255a008b9008177926ba2cc"  # qtcamera
requires "https://github.com/status-im/nim-qrscan#5e66fe20d1a7913d25599515cc6faad2aeae7a2b"  # qrscan
# Transitive packages, pinned to the revisions the app was built with as submodules.
requires "isaac == 0.2.0"  # isaac (uuids); by version: uuids requires it by version
requires "https://github.com/status-im/nim-secp256k1.git#4e1ccd554777e4f9f790176bcffd8009a75fd2b7"  # secp256k1 (eth)
requires "https://github.com/status-im/nim-metrics#9f2e1d4a4164deb37603b16cedd1707408ee5955"  # metrics (eth)
requires "https://github.com/status-im/nim-zlib.git#7b1d6ed291df9fddcbb5cf16c1968c2b8c6e5a90"  # zlib (websock)
requires "https://github.com/status-im/nim-serialization#937a65c19fc49a5f79e2ecd89094d367b6ca0e1b"  # serialization (json_serialization)
requires "https://github.com/vacp2p/nim-intops.git#ade5d78d60124d1fd50d2109c5eb9416ed147231"  # intops (stint)
requires "https://github.com/status-im/nim-faststreams.git#5bdef9939b483435a61aa91a6422c1a9852127b4"  # faststreams (serialization)
requires "https://github.com/status-im/nim-protobuf-serialization#a671c6d497c7028ed7390b2d5a80c7b62138c586"  # protobuf_serialization (sds)
requires "https://github.com/status-im/nim-snappy#a99d113197e81bf764a3b005b0ade3f9f3758069"  # snappy (eth)
requires "https://github.com/nitely/nim-unicodedb.git#b70aac15a3fdc7647997bd6cd10bccd8b2c00e54"  # unicodedb (regex)
