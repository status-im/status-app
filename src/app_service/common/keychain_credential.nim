import json, chronicles

import ../../backend/privacy as status_privacy
import ./utils

logScope:
  topics = "keychain-credential"

const DEK_CREDENTIAL_PREFIX* = "dek:"

proc biometricCredentialForPasswordProfile*(keyUid: string, password: string): string =
  ## Returns the value to store in the OS keychain for biometric login for a password based profile.
  ## Keycard profiles store the PIN directly and must never go through here.
  ## - profile migrated to DEK encryption -> "dek:<64-hex>" (the wrapped DEK, tagged)
  ## - legacy profile                     -> the raw password (current behavior preserved)
  ## - failure                            -> "" (don't save, or delete the existing item)
  ## When `password` is already the raw DEK (a re-save after a dek-tagged biometric auth), the value is returned as is.
  try:
    let info = status_privacy.getProfileEncryptionInfo(keyUid)
    if info.result.isNil or info.result.kind != JObject or
        info.result{"error"}.getStr.len > 0 or
        not info.result.hasKey("migrated") or info.result["migrated"].kind != JBool:
      error "unexpected profile encryption info response", keyUid
      return ""
    if not info.result["migrated"].getBool:
      return password
    let response = status_privacy.exportProfileDEK(keyUid, hashPassword(password))
    let dek = response.result{"dek"}.getStr
    if dek.len == 0:
      error "export-profile-dek returned no DEK", keyUid, err = response.result{"error"}.getStr
      return ""
    return DEK_CREDENTIAL_PREFIX & dek
  except Exception as e:
    error "failed to prepare biometric credential", errName = e.name, errDesription = e.msg
    return ""
