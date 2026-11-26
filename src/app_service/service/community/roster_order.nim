## Canonical member order of a community roster (CONTEXT.md): online first,
## then case-folded preferred display name, then key. The snapshot is sorted on
## the load worker; the roster model keeps the order with single-row moves.

import std/[algorithm, sets, tables]

import ./dto/roster
import app/modules/shared_models/contacts_utils

type
  ## Contacts-cache name fields. Known (self, or a record status-go sent, kept
  ## live by contact updates): they replace the roster entry's, empty included;
  ## otherwise (a placeholder, or not cached) the entry's apply.
  RosterNames* = object
    known*: bool
    localNickname*: string
    displayName*: string
    ensName*: string
    ensVerified*: bool
    alias*: string

  ## What the load worker cannot read: online members and the contacts-cache
  ## names (status-go records, own profile), keyed by "0x04…" key.
  RosterOrderInputs* = object
    online*: seq[string]
    names*: Table[string, RosterNames]

proc resolveNames*(member: RosterMember, names: RosterNames): RosterNames =
  ## The name fields a member row shows.
  if names.known:
    return names
  RosterNames(localNickname: names.localNickname, displayName: member.displayName,
    ensName: member.ensName, ensVerified: member.ensVerified, alias: member.alias)

proc preferredName*(names: RosterNames): string =
  ## Of resolved names; an unverified ENS name is no name.
  resolvePreferredDisplayName(names.localNickname, (if names.ensVerified: names.ensName else: ""),
    names.displayName, names.alias)

proc preferredName*(member: RosterMember, names: RosterNames): string =
  preferredName(resolveNames(member, names))

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
