import std/[unittest, strutils]

import app_service/common/pubkey_codec

# Vectors from status-go multiformat.SerializePublicKey("0xe701" & key, "z")
# (what backend/accounts.compressPk calls) on the keys of private keys 1, 2, 3
# (even Y) and 6, 9, 11 (odd Y).
const vectors = [
  ("0x0479be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8",
   "zQ3shVc2UkAfJCdc1TR8E66J85h48P43r93q8jGPkPpjF9Ef9"),
  ("0x04c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee51ae168fea63dc339a3c58419466ceaeef7f632653266d0e1236431a950cfe52a",
   "zQ3shajmTb29MxR6htjD79Hdo6vneJLvyKCzZSRcawNWks9JC"),
  ("0x04f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9388f7b0f632de8140fe337e62a37f3566500a99934c2231b6cb9fd7584b8e672",
   "zQ3sheBXCeZNNKcYTSbn3U6mTZD228vEFA753n76azCDQq16g"),
  ("0x04fff97bd5755eeea420453a14355235d382f6472f8568a18b2f057a1460297556ae12777aacfbb620f3be96017f45c560de80f0f6518fe4a03c870c36b075f297",
   "zQ3shwsKjaUybhiRNQxfVhgov8p2azuk11Sw1QRNTUx2FmRZP"),
  ("0x04acd484e2f0c7f65309ad178a9f559abde09796974c57e714c35f110dfc27ccbecc338921b0a7d9fd64380971763b61e9add888a4375f8e0f05cc262ac64f9c37",
   "zQ3shrGmCoTCErYxxXeFrEZNKDFbFKMFoytYULeH2CuoPaQb7"),
  ("0x04774ae7f858a9411e5ef4246b70c65aac5649980be5c17891bbec17895da008cbd984a032eb6b5e190243dd56d7b7b365372db1e2dff9d6a8301d74c9c953c61b",
   "zQ3shnfmtcakNo1kYVcNsV3JK3xTPknSLF5oniX8csZcNVBHt"),
]

suite "pubkey codec":
  test "compressedPubKey matches status-go compressPk":
    for (hex, compressed) in vectors:
      var key: RawPubKey
      check parseRawPubKey(hex, key)
      check compressedPubKey(key) == compressed

  test "hex round trip":
    for (hex, _) in vectors:
      var key: RawPubKey
      check parseRawPubKey(hex, key)
      check toPubKeyHex(key) == hex

  test "parse accepts upper-case hex":
    var a, b: RawPubKey
    check parseRawPubKey(vectors[0][0], a)
    check parseRawPubKey("0x04" & vectors[0][0][4..^1].toUpperAscii, b)
    check a == b

  test "parse rejects malformed keys":
    var key: RawPubKey
    check not parseRawPubKey("", key)
    check not parseRawPubKey("0x04abcd", key)
    # compressed form
    check not parseRawPubKey("0x0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798", key)
    # wrong prefix byte
    check not parseRawPubKey("0x05" & vectors[0][0][4..^1], key)
    # non-hex digit
    check not parseRawPubKey("0x04" & vectors[0][0][4..^2] & "g", key)
