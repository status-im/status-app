
import unittest
import json

import app_service/service/accounts/dto/accounts
import app_service/service/accounts/dto/create_account_request

suite "AccountDto zeroOnboarded":

  test "parsed when status-go marks the profile":
    let dto = toAccountDto(%*{"name": "a", "key-uid": "0x1", "zeroOnboarded": true})
    check dto.zeroOnboarded == true

  test "missing field means a regular profile":
    # status-go omits the field (omitempty) for regular profiles
    let dto = toAccountDto(%*{"name": "a", "key-uid": "0x1"})
    check dto.zeroOnboarded == false

  test "explicit false is a regular profile":
    let dto = toAccountDto(%*{"name": "a", "key-uid": "0x1", "zeroOnboarded": false})
    check dto.zeroOnboarded == false

suite "CreateAccountRequest zeroOnboarded":

  test "serialized when set":
    check CreateAccountRequest(zeroOnboarded: true).toJson()["zeroOnboarded"].getBool() == true

  test "serialized as false by default":
    check CreateAccountRequest().toJson()["zeroOnboarded"].getBool() == false
