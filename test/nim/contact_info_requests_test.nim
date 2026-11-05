import std/[importutils, json, sets, tables, unittest]
import app/core/eventemitter
import app_service/service/contacts/service as contacts_service
from seaqt/qcoreapplication import QCoreApplication, create

privateAccess(contacts_service.Service)

discard QCoreApplication.create()

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
    check completions.len == 1
    check completions[0].ok

  test "empty keys fail explicitly without dispatch":
    service.requestContactInfo("")
    check service.contactInfoRequests.len == 0
    check completions.len == 1
    check not completions[0].ok
