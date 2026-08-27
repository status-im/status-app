## Unit tests for the tagged-DEK credential shape check backing "Stay logged in".
##
## IMPORTANT: shape is defense-in-depth, never authorization. The guarantee that a raw
## password can never reach the silently readable store — even a legacy password shaped
## exactly like a tagged DEK — is structural: dekCredentialForPasswordProfile
## (app_service/common/keychain_credential) returns a tagged DEK only for a
## confirmed-migrated profile with a successful DEK export, and "" otherwise. That
## function requires the status-go backend and is exercised by the QML/e2e layers; these
## tests pin down the pure shape validator it is paired with.

import unittest
import std/strutils

import app_service/common/utils

const validHex64 = "0123456789abcdef".repeat(4) # 64 lowercase hex chars

suite "isTaggedDekCredential":

  test "valid tagged DEK passes":
    check isTaggedDekCredential(DEK_CREDENTIAL_PREFIX & validHex64) == true

  test "missing prefix fails":
    check isTaggedDekCredential(validHex64) == false

  test "prefix alone fails":
    check isTaggedDekCredential(DEK_CREDENTIAL_PREFIX) == false

  test "empty string fails":
    check isTaggedDekCredential("") == false

  test "wrong hex length fails":
    check isTaggedDekCredential(DEK_CREDENTIAL_PREFIX & validHex64[0 ..< 63]) == false
    check isTaggedDekCredential(DEK_CREDENTIAL_PREFIX & validHex64 & "a") == false

  test "uppercase hex fails (status-go normalizes to lowercase)":
    check isTaggedDekCredential(DEK_CREDENTIAL_PREFIX & validHex64.toUpperAscii()) == false

  test "non-hex characters fail":
    check isTaggedDekCredential(DEK_CREDENTIAL_PREFIX & "g".repeat(64)) == false
    check isTaggedDekCredential(DEK_CREDENTIAL_PREFIX & validHex64[0 ..< 63] & " ") == false
    check isTaggedDekCredential(DEK_CREDENTIAL_PREFIX & validHex64[0 ..< 63] & "-") == false

  test "ordinary passwords fail":
    check isTaggedDekCredential("hunter2") == false
    check isTaggedDekCredential("dek:my-password") == false
    check isTaggedDekCredential("0x" & validHex64) == false

  test "a DEK-shaped password passes the SHAPE check — which is exactly why shape is not authorization":
    # A user could genuinely choose this as a password. The silent store is protected
    # from it structurally: the password conversion path returns "" for non-migrated
    # profiles and only ever emits a freshly exported DEK for migrated ones — a
    # password's text never flows through to storage (see file header).
    check isTaggedDekCredential(DEK_CREDENTIAL_PREFIX & validHex64) == true
