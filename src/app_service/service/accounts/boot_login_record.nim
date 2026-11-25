## The boot-login record: the init and login requests of the last login with "Stay logged
## in" on, replayed by the Android service after a phone restart. The service adds the DEK
## from the prompt-free secure store and the app versionCode at write time, so the record
## itself never holds a login secret.

import std/json

const BOOT_LOGIN_RECORD_VERSION* = 1

const loginSecretKeys = ["password", "dek", "mnemonic", "keycardWhisperPrivateKey"]

proc buildBootLoginRecord*(keyUid: string, initRequest: JsonNode, loginRequest: JsonNode): string =
  if keyUid.len == 0:
    return ""
  let login = loginRequest.copy()
  for key in loginSecretKeys:
    if login.hasKey(key):
      login.delete(key)
  return $(%* {
    "version": BOOT_LOGIN_RECORD_VERSION,
    "keyUid": keyUid,
    "initRequest": initRequest,
    "loginRequest": login,
  })
