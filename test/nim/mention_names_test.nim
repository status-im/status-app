import std/[unittest, tables]

import app_service/service/contacts/dto/contacts
import app_service/service/contacts/dto/contact_details
import app_service/service/message/mention_names

const key = "0x04aa"

proc fakeAlias(pubKey: string): string = "alias-" & pubKey

proc details(dto: ContactsDto): ContactDetails =
  ContactDetails(dto: dto)

suite "mentionDisplayName":

  test "named cached contact wins over status-go name":
    var cached = details(ContactsDto(id: key, alias: "a", localNickname: "nick", displayName: "name"))
    check mentionDisplayName(addr cached, {key: "go-name"}.toTable, key, fakeAlias) == "nick"

  test "added cached contact wins even without a name":
    var cached = details(ContactsDto(id: key, alias: "a", added: true))
    check mentionDisplayName(addr cached, {key: "go-name"}.toTable, key, fakeAlias) == "a"

  test "alias-only cached contact falls back to the status-go name":
    var cached = details(ContactsDto(id: key, alias: "a"))
    check mentionDisplayName(addr cached, {key: "go-name"}.toTable, key, fakeAlias) == "go-name"

  test "unverified ENS is not a name of its own":
    var cached = details(ContactsDto(id: key, alias: "a", name: "fake.eth"))
    check mentionDisplayName(addr cached, {key: "go-name"}.toTable, key, fakeAlias) == "go-name"

  test "uncached key uses the status-go name":
    check mentionDisplayName(nil, {key: "go-name"}.toTable, key, fakeAlias) == "go-name"

  test "unknown key uses the cached alias, then a generated one":
    var cached = details(ContactsDto(id: key, alias: "a"))
    check mentionDisplayName(addr cached, initTable[string, string](), key, fakeAlias) == "a"
    check mentionDisplayName(nil, initTable[string, string](), key, fakeAlias) == "alias-" & key

  test "self uses the live own-profile name, not the stale status-go one":
    const me = "0x04bb"
    let mentioned = {me: "old name"}.toTable
    check mentionDisplayName(nil, mentioned, me, fakeAlias, MentionSelf(pubKey: me, name: "new name")) == "new name"
    # someone else is unaffected
    check mentionDisplayName(nil, {key: "go-name"}.toTable, key, fakeAlias,
      MentionSelf(pubKey: me, name: "new name")) == "go-name"
