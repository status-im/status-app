import unittest

import app/modules/main/wallet_section/following_addresses/item

suite "following address item":
  test "name prefers ens over address":
    let withEns = initItem("0xabc", "vitalik.eth", @["ens"], "https://example.com/a.png")

    check withEns.getAddress() == "0xabc"
    check withEns.getEnsName() == "vitalik.eth"
    check withEns.getName() == "vitalik.eth"
    check withEns.getTags() == @["ens"]
    check withEns.getAvatar() == "https://example.com/a.png"
    check not withEns.isEmpty()

  test "name falls back to address and empty address is empty":
    check initItem("0xabc", "", @[], "").getName() == "0xabc"
    check initItem("", "vitalik.eth", @[], "").isEmpty()
