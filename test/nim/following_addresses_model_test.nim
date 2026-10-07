import unittest, tables

import nimqml

import app/modules/main/wallet_section/following_addresses/model

proc roleForName(list: Model, name: string): int =
  for role, roleName in list.roleNames().pairs:
    if roleName == name:
      return role
  return -1

proc stringData(list: Model, row: int, roleName: string): string =
  let idx = list.createIndex(row, 0, nil)
  return list.data(idx, roleForName(list, roleName)).stringVal

suite "following addresses model":
  test "setItems replaces the list and exposes roles":
    let list = newModel()
    check list.rowCount(nil) == 0
    check list.getCount() == 0

    list.setItems(@[
      initItem("0xAbC", "vitalik.eth", @["ens", "efp"], "https://example.com/a.png"),
      initItem("0xdef", "", @[], ""),
    ])

    check list.rowCount(nil) == 2
    check list.getCount() == 2
    check stringData(list, 0, "address") == "0xAbC"
    check stringData(list, 0, "ensName") == "vitalik.eth"
    check stringData(list, 0, "tags") == "ens,efp"
    check stringData(list, 0, "name") == "vitalik.eth"
    check stringData(list, 0, "avatar") == "https://example.com/a.png"
    check stringData(list, 1, "name") == "0xdef"

  test "lookup is case-insensitive and misses return an empty item":
    let list = newModel()
    list.setItems(@[initItem("0xAbC", "vitalik.eth", @[], "")])

    let found = list.getItemByAddress("0xabc")
    check found.getEnsName() == "vitalik.eth"
    check list.getItemByAddress("0xmissing").isEmpty()
    check list.getItemByAddress("").isEmpty()
