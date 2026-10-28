import std/[unittest, json, strutils]

import app_service/service/keycardV2/dto

suite "keycardV2 dto: secure channel generation":
  test "applet 3.x status: pairing supported":
    let info = toKeycardInfoDto(%*{
      "initialized": true,
      "instanceUID": "11111111111111111111111111111111",
      "version": "3.2",
      "availableSlots": 0,
      "keyUID": "abcd",
      "secureChannelVersion": 1,
    })
    check info.secureChannelVersion == 1
    check info.pairingSupported()
    check info.availableSlots == 0
    check info.keyUID == "0xabcd"

  test "applet 4.x status: no pairing":
    let info = toKeycardInfoDto(%*{
      "initialized": true,
      "instanceUID": "22222222222222222222222222222222",
      "version": "4.0",
      "availableSlots": 0,
      "keyUID": "",
      "secureChannelVersion": 2,
    })
    check info.secureChannelVersion == 2
    check not info.pairingSupported()

  test "older library without secureChannelVersion: treated as applet 3.x":
    let info = toKeycardInfoDto(%*{"instanceUID": "33", "availableSlots": 4})
    check info.secureChannelVersion == 1
    check info.pairingSupported()

suite "keycardV2 dto: certificate trust":
  test "card from an unknown CA is reported, not refused":
    let info = toKeycardInfoDto(%*{"instanceUID": "44", "secureChannelVersion": 2, "certificateTrusted": false})
    check info.certificateUntrusted
    check not info.pairingSupported()

  test "trusted card":
    check not toKeycardInfoDto(%*{"instanceUID": "66", "certificateTrusted": true}).certificateUntrusted

  test "missing or null field means no warning (applet 3.x, older library)":
    check not toKeycardInfoDto(%*{"instanceUID": "55"}).certificateUntrusted
    check not toKeycardInfoDto(%*{"instanceUID": "55", "certificateTrusted": nil}).certificateUntrusted

  test "event without keycardInfo means no warning":
    check not toKeycardEventDto(%*{"state": "waiting-for-card"}).keycardInfo.certificateUntrusted
    check not KeycardEventDto().keycardInfo.certificateUntrusted

suite "keycardV2 dto: untrusted keycard state":
  test "maps to KeycardState.UntrustedKeycard":
    check parseEnum[StateString]("untrusted-keycard") == StateString.UntrustedKeycard
    check fromStringStateToInt(StateString.UntrustedKeycard) == KeycardState.UntrustedKeycard
