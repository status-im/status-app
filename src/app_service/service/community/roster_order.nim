## Canonical member order of a community roster (CONTEXT.md): online first,
## then case-folded preferred display name, then key. The snapshot is sorted on
## the load worker; the roster model keeps the order with single-row moves.

import std/[algorithm, sets, tables]

import ./dto/roster
import app/modules/shared_models/contacts_utils

type
  ## Contacts-cache name fields that win over the roster entry's.
  RosterNames* = object
    localNickname*: string
    displayName*: string
    ensName*: string
    ensVerified*: bool
    alias*: string

  ## What the load worker cannot read: online members and the names of
  ## contacts (nicknames, own profile), keyed by "0x04…" key.
  RosterOrderInputs* = object
    online*: seq[string]
    names*: Table[string, RosterNames]

proc preferredName*(member: RosterMember, names: RosterNames): string =
  ## The name a member row shows; an unverified ENS name is no name.
  let displayName = if names.displayName.len > 0: names.displayName else: member.displayName
  let fromNamesEns = names.ensName.len > 0
  let ensName = if fromNamesEns: names.ensName else: member.ensName
  let ensVerified = if fromNamesEns: names.ensVerified else: member.ensVerified
  let alias = if names.alias.len > 0: names.alias else: member.alias
  resolvePreferredDisplayName(names.localNickname, (if ensVerified: ensName else: ""),
    displayName, alias)

proc cmpKeys(a, b: RawPubKey): int =
  for i in 0 ..< a.len:
    if a[i] != b[i]:
      return cmp(a[i], b[i])

proc cmpRosterOrder*(a: RosterSortKey, aKey: RawPubKey, b: RosterSortKey, bKey: RawPubKey): int =
  ## Total: the key leg leaves exactly one place for every member.
  result = cmp(b.online, a.online)
  if result == 0:
    result = cmpFoldedNames(a.name, b.name)
  if result == 0:
    result = cmpKeys(aKey, bKey)

proc sortRoster*(snapshot: var RosterSnapshot, inputs: RosterOrderInputs) =
  ## Sorts the members and sets their sort keys.
  var online = initHashSet[RawPubKey](inputs.online.len)
  for pubKey in inputs.online:
    var key: RawPubKey
    if parseRawPubKey(pubKey, key):
      online.incl key
  var names = initTable[RawPubKey, RosterNames](inputs.names.len)
  for pubKey, entry in inputs.names.pairs:
    var key: RawPubKey
    if parseRawPubKey(pubKey, key):
      names[key] = entry
  let count = snapshot.members.len
  var keys = newSeq[RosterSortKey](count)
  var memberKeys = newSeq[RawPubKey](count)
  var order = newSeq[int](count)
  for i, member in snapshot.members:
    keys[i] = RosterSortKey(online: member.key in online,
      name: preferredName(member, names.getOrDefault(member.key)))
    memberKeys[i] = member.key
    order[i] = i
  order.sort(proc(i, j: int): int =
    cmpRosterOrder(keys[i], memberKeys[i], keys[j], memberKeys[j]))
  var sorted = newSeqOfCap[RosterMember](count)
  snapshot.sortKeys = newSeqOfCap[RosterSortKey](count)
  for i in order:
    sorted.add move(snapshot.members[i])
    snapshot.sortKeys.add move(keys[i])
  snapshot.members = move(sorted)
