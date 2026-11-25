## Unit tests for the boot-login record: the init and login requests the Android service
## replays after a phone restart. The record must never carry the DEK or the password hash.

import unittest
import std/[json, strutils]

import app_service/service/accounts/boot_login_record
import app_service/service/accounts/dto/login_request as login_request_dto

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
    # Built by the real request serializer, so a renamed secret key fails here
    let request = LoginAccountRequest(keyUID: "0xkeyuid", passwordHash: "secret-password-hash",
      dek: "secret-dek", mnemonic: "secret-mnemonic",
      keycardWhisperPrivateKey: "secret-whisper-key").toJson()
    let record = buildBootLoginRecord("0xkeyuid", initRequest, request)
    check record.len > 0
    check "secret-" notin record
    check parseJson(record)["loginRequest"]["keyUid"].getStr == "0xkeyuid"

  test "leaves the caller's request untouched":
    discard buildBootLoginRecord("0xkeyuid", initRequest, loginRequest)
    check loginRequest["dek"].getStr == "a1b2"
    check loginRequest["password"].getStr == "0xhashedpassword"

  test "a request without some secret fields is still accepted":
    let record = parseJson(buildBootLoginRecord("0xkeyuid", initRequest, %* {"keyUid": "0xkeyuid", "dek": "a1b2"}))
    check record["loginRequest"] == %* {"keyUid": "0xkeyuid"}

  test "no profile, no record":
    check buildBootLoginRecord("", initRequest, loginRequest) == ""

suite "resumedSessionKeepsBootLoginRecord":

  test "a resumed password profile with Stay logged in on keeps its record current":
    check resumedSessionKeepsBootLoginRecord(stayLoggedIn = true, keycardProfile = false)

  test "Stay logged in off: no record":
    check not resumedSessionKeepsBootLoginRecord(stayLoggedIn = false, keycardProfile = false)

  test "a keycard profile never gets a record":
    check not resumedSessionKeepsBootLoginRecord(stayLoggedIn = true, keycardProfile = true)
