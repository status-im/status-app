import unittest, json

import app/modules/shared/wallet_utils
import app_service/service/wallet_account/dto/account_dto

proc mkAccount(address: string, hideFromTotalBalance: bool): WalletAccountDto =
  WalletAccountDto(address: address, hideFromTotalBalance: hideFromTotalBalance)

suite "addressesNotHiddenFromTotalBalance":

  test "mix of generated and hidden watch-only keeps only visible addresses":
    let accounts = @[
      mkAccount("0xgenerated", false),
      mkAccount("0xwatched", true)
    ]
    check addressesNotHiddenFromTotalBalance(accounts) == @["0xgenerated"]

  test "all hidden returns an empty seq":
    let accounts = @[
      mkAccount("0xone", true),
      mkAccount("0xtwo", true)
    ]
    check addressesNotHiddenFromTotalBalance(accounts).len == 0

  test "none hidden returns every address":
    let accounts = @[
      mkAccount("0xone", false),
      mkAccount("0xtwo", false)
    ]
    check addressesNotHiddenFromTotalBalance(accounts) == @["0xone", "0xtwo"]

  test "empty input returns empty seq":
    check addressesNotHiddenFromTotalBalance(@[]).len == 0

  test "toWalletAccountDto maps JSON hidden onto hideFromTotalBalance":
    let hidden = toWalletAccountDto(%*{
      "address": "0xwatched",
      "hidden": true
    })
    check hidden.hideFromTotalBalance
    check hidden.address == "0xwatched"

    let visible = toWalletAccountDto(%*{
      "address": "0xgenerated",
      "hidden": false
    })
    check(not visible.hideFromTotalBalance)
