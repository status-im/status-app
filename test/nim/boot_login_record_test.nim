## Unit tests for the boot-login record: the init and login requests the Android service
## replays after a phone restart. The record must never carry the DEK or the password hash.

import unittest
import std/json

import app_service/service/accounts/boot_login_record

let initRequest = %* {"dataDir": "/data/status", "logEnabled": true}
let loginRequest = %* {
  "password": "0xhashedpassword",
  "dek": "a1b2",
  "mnemonic": "",
  "keycardWhisperPrivateKey": "",
  "keyUid": "0xkeyuid",
  "kdfIterations": 3200,
  "walletConnectProjectID": "wc-id",
  "apiConfig": {"apiModules": "wakuext"},
}

suite "buildBootLoginRecord":

  test "wraps both requests with the version and the profile":
    let record = parseJson(buildBootLoginRecord("0xkeyuid", initRequest, loginRequest))
    check record["version"].getInt == 1
    check record["keyUid"].getStr == "0xkeyuid"
    check record["initRequest"] == initRequest
    check record["loginRequest"]["keyUid"].getStr == "0xkeyuid"
    check record["loginRequest"]["kdfIterations"].getInt == 3200
    check record["loginRequest"]["walletConnectProjectID"].getStr == "wc-id"
    check record["loginRequest"]["apiConfig"] == %* {"apiModules": "wakuext"}

  test "never contains the DEK, the password hash or other login secrets":
    let record = parseJson(buildBootLoginRecord("0xkeyuid", initRequest, loginRequest))
    let login = record["loginRequest"]
    check not login.hasKey("dek")
    check not login.hasKey("password")
    check not login.hasKey("mnemonic")
    check not login.hasKey("keycardWhisperPrivateKey")

  test "leaves the caller's request untouched":
    discard buildBootLoginRecord("0xkeyuid", initRequest, loginRequest)
    check loginRequest["dek"].getStr == "a1b2"
    check loginRequest["password"].getStr == "0xhashedpassword"

  test "a request without some secret fields is still accepted":
    let record = parseJson(buildBootLoginRecord("0xkeyuid", initRequest, %* {"keyUid": "0xkeyuid", "dek": "a1b2"}))
    check record["loginRequest"] == %* {"keyUid": "0xkeyuid"}

  test "no profile, no record":
    check buildBootLoginRecord("", initRequest, loginRequest) == ""
