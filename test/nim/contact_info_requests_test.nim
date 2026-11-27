import std/[importutils, json, sets, tables, unittest]
import app/core/eventemitter
import app_service/common/types
import app_service/service/contacts/service as contacts_service
import ./support/qt_app

privateAccess(contacts_service.Service)

ensureQtCoreApp()

suite "contact info request coalescing":
  setup:
    let events = createEventEmitter()
    let service = contacts_service.newService(events, nil, nil, nil)
    var completions: seq[ContactInfoRequestArgs]
    events.on(SIGNAL_CONTACT_INFO_REQUEST_FINISHED) do(args: Args):
      completions.add(ContactInfoRequestArgs(args))

  test "repeated callers join an existing request without scheduling another RPC":
    service.contactInfoRequests.incl("profile")
    for i in 0 ..< 20:
      # No pool is installed: attempting to dispatch a duplicate would fail.
      service.requestContactInfo("profile")
    check service.contactInfoRequests.len == 1
    check completions.len == 0

  test "worker errors release the key and notify all subscribers":
    var secondSubscriber: seq[bool]
    events.on(SIGNAL_CONTACT_INFO_REQUEST_FINISHED) do(args: Args):
      secondSubscriber.add(ContactInfoRequestArgs(args).ok)
    service.contactInfoRequests.incl("profile")
    service.contactInfoRequests.incl("other-profile")
    service.asyncContactInfoLoaded($ %* {
      "publicKey": "profile", "error": "store node timed out"
    })
    check "profile" notin service.contactInfoRequests
    check "other-profile" in service.contactInfoRequests
    check completions.len == 1
    check completions[0].publicKey == "profile"
    check not completions[0].ok
    check secondSubscriber == @[false]

  test "RPC errors and invalid contacts release the request for retry":
    for response in [
      %* {"publicKey": "profile", "error": "", "response": {
        "error": {"code": -1, "message": "lookup failed"}
      }},
      %* {"publicKey": "profile", "response": {"result": nil}},
      %* {"publicKey": "profile", "response": {"result": {"id": "other-profile"}}}
    ]:
      service.contactInfoRequests.incl("profile")
      service.asyncContactInfoLoaded($response)
      check "profile" notin service.contactInfoRequests
      check completions[^1].publicKey == "profile"
      check not completions[^1].ok
    check completions.len == 3

  test "successful lookup updates the cache and releases the key before notification":
    var pendingAtNotification = true
    events.on(SIGNAL_CONTACT_INFO_REQUEST_FINISHED) do(args: Args):
      pendingAtNotification = "profile" in service.contactInfoRequests
    service.contactInfoRequests.incl("profile")
    service.asyncContactInfoLoaded($ %* {
      "publicKey": "profile", "error": "", "response": {"result": {
        "id": "profile", "displayName": "Fetched profile", "alias": "test-alias"
      }}
    })
    check not pendingAtNotification
    check "profile" notin service.contactInfoRequests
    check service.contacts["profile"].dto.displayName == "Fetched profile"
    check service.contacts["profile"].fromStatusGo
    check service.statusGoContactKeys() == @["profile"]
    check completions.len == 1
    check completions[0].ok

  test "a placeholder is not a status-go record until status-go sends one":
    const key = "0x0479be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8"
    service.seedFromChatMembers(@[MemberSeed(id: key, alias: "Zany Mammoth Hare",
      compressedPubKey: "zQ3sh", emojiHash: "[\"x\"]", colorId: 4)])
    check service.contacts.hasKey(key)
    check not service.contacts[key].fromStatusGo
    check service.statusGoContactKeys().len == 0
    service.contactInfoRequests.incl(key)
    service.asyncContactInfoLoaded($ %* {
      "publicKey": key, "error": "", "response": {"result": {"id": key, "displayName": "alice"}}
    })
    check service.contacts[key].fromStatusGo
    check service.contacts[key].dto.alias == "Zany Mammoth Hare"

  test "empty keys fail explicitly without dispatch":
    service.requestContactInfo("")
    check service.contactInfoRequests.len == 0
    check completions.len == 1
    check not completions[0].ok
