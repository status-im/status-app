import unittest, json

import app_service/service/following_address/dto

suite "following address dto":
  test "parses address, tags, ens, avatar and records":
    let node = parseJson("""
      {
        "address": "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
        "tags": ["ens", "efp"],
        "ensName": "vitalik.eth",
        "avatar": "https://example.com/avatar.png",
        "records": {"com.twitter": "vitalikbuterin"}
      }
    """)
    let parsed = node.toFollowingAddressDto()

    check parsed.address == "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
    check parsed.tags == @["ens", "efp"]
    check parsed.ensName == "vitalik.eth"
    check parsed.avatar == "https://example.com/avatar.png"
    check parsed.records["com.twitter"].getStr() == "vitalikbuterin"

  test "missing tags and records default to empty":
    let node = parseJson("""{"address": "0xabc"}""")
    let parsed = node.toFollowingAddressDto()

    check parsed.address == "0xabc"
    check parsed.tags.len == 0
    check parsed.ensName == ""
    check parsed.avatar == ""
    check parsed.records.kind == JObject
    check parsed.records.len == 0

  test "non-string tags are ignored":
    let node = parseJson("""{"address": "0xabc", "tags": ["ok", 1, null]}""")
    check node.toFollowingAddressDto().tags == @["ok"]
