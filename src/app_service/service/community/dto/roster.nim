## Community roster wire types (the status-go getCommunityMembers snapshot and the
## roster keys of `communityChanges[]`). Keys are kept raw; hex only on the wire.

import std/[json, tables]

import ../../../common/[pubkey_codec, types]

export pubkey_codec

type
  ChannelRole* {.pure.} = enum
    Poster = 0
    Viewer = 1

  RosterMember* = object
    key*: RawPubKey
    role*: MemberRole
    ensVerified*: bool
    colorId*: int
    thumbnailImageClock*: uint64
    displayName*: string
    ensName*: string
    # set only when the member has no known display name
    alias*: string

  ChannelMember* = object
    key*: RawPubKey
    role*: ChannelRole

  ChannelMembersDelta* = object
    chatId*: string
    added*: seq[ChannelMember]
    removed*: seq[RawPubKey]
    modified*: seq[ChannelMember]

  RosterDelta* = object
    communityId*: string
    clock*: uint64
    added*: seq[RosterMember]
    removed*: seq[RawPubKey]
    modified*: seq[RosterMember]
    channels*: seq[ChannelMembersDelta]
    # a token permission was added, modified or removed: which channels are
    # gated, and who is in them, may have changed
    permissionsChanged*: bool

  RosterSnapshot* = object
    clock*: uint64
    members*: seq[RosterMember]
    # token-gated channels only, keyed by channel id (without the community prefix)
    channels*: Table[string, seq[ChannelMember]]

proc toMemberRole*(roles: openArray[int]): MemberRole =
  for role in [MemberRole.Owner, MemberRole.Admin, MemberRole.ManageUsers,
      MemberRole.ModerateContent, MemberRole.TokenMaster]:
    if role.int in roles:
      return role
  MemberRole.None

proc toChannelRole(node: JsonNode): ChannelRole =
  if node.getInt() == ChannelRole.Viewer.int: ChannelRole.Viewer else: ChannelRole.Poster

proc parseRosterMember*(node: JsonNode, member: var RosterMember): bool =
  if node.kind != JObject or not parseRawPubKey(node{"pubKey"}.getStr(), member.key):
    return false
  var roles: seq[int]
  for role in node{"roles"}.getElems():
    roles.add role.getInt()
  member.role = toMemberRole(roles)
  member.displayName = node{"displayName"}.getStr()
  member.ensName = node{"ensName"}.getStr()
  member.ensVerified = node{"ensVerified"}.getBool()
  member.alias = node{"alias"}.getStr()
  member.colorId = node{"colorId"}.getInt()
  member.thumbnailImageClock = uint64(node{"thumbnailImageClock"}.getBiggestInt())
  true

proc parseRosterSnapshot*(node: JsonNode): RosterSnapshot =
  result.clock = uint64(node{"clock"}.getBiggestInt())
  let members = node{"members"}
  if not members.isNil and members.kind == JArray:
    result.members = newSeqOfCap[RosterMember](members.len)
    for entry in members.elems:
      var member: RosterMember
      if parseRosterMember(entry, member):
        result.members.add move(member)
  let channels = node{"channels"}
  if not channels.isNil and channels.kind == JObject:
    for chatId, channelMembers in channels.fields:
      var parsed: seq[ChannelMember]
      if channelMembers.kind == JObject:
        for pubKey, role in channelMembers.fields:
          var key: RawPubKey
          if parseRawPubKey(pubKey, key):
            parsed.add ChannelMember(key: key, role: toChannelRole(role))
      result.channels[chatId] = parsed

proc parseRosterEntries(node: JsonNode, into: var seq[RosterMember]) =
  if node.isNil or node.kind != JObject:
    return
  for _, entry in node.fields:
    var member: RosterMember
    if parseRosterMember(entry, member):
      into.add move(member)

# chatsModified members are protobuf CommunityMember objects keyed by pubkey;
# only the channel role is used
proc parseChannelMembers(node: JsonNode, into: var seq[ChannelMember]) =
  if node.isNil or node.kind != JObject:
    return
  for pubKey, member in node.fields:
    var key: RawPubKey
    if parseRawPubKey(pubKey, key):
      into.add ChannelMember(key: key, role: toChannelRole(member{"channel_role"}))

proc isEmpty*(self: ChannelMembersDelta): bool =
  self.added.len == 0 and self.removed.len == 0 and self.modified.len == 0

proc isEmpty*(self: RosterDelta): bool =
  self.added.len == 0 and self.removed.len == 0 and self.modified.len == 0 and
    self.channels.len == 0 and not self.permissionsChanged

proc parseRosterDelta*(node: JsonNode, delta: var RosterDelta): bool =
  ## One `communityChanges[]` element; false when it names no community.
  delta.communityId = node{"communityId"}.getStr()
  if delta.communityId.len == 0:
    return false
  delta.clock = uint64(node{"clock"}.getBiggestInt())
  parseRosterEntries(node{"rosterAdded"}, delta.added)
  parseRosterEntries(node{"rosterModified"}, delta.modified)
  let removed = node{"rosterRemoved"}
  if not removed.isNil and removed.kind == JObject:
    for pubKey, _ in removed.fields:
      var key: RawPubKey
      if parseRawPubKey(pubKey, key):
        delta.removed.add key
  let chats = node{"chatsModified"}
  if not chats.isNil and chats.kind == JObject:
    for chatId, changes in chats.fields:
      var channel = ChannelMembersDelta(chatId: chatId)
      parseChannelMembers(changes{"MembersAdded"}, channel.added)
      parseChannelMembers(changes{"MembersModified"}, channel.modified)
      var removedMembers: seq[ChannelMember]
      parseChannelMembers(changes{"MembersRemoved"}, removedMembers)
      for member in removedMembers:
        channel.removed.add member.key
      if not channel.isEmpty:
        delta.channels.add move(channel)
  for key in ["tokenPermissionsAdded", "tokenPermissionsModified", "tokenPermissionsRemoved"]:
    let permissions = node{key}
    if not permissions.isNil and permissions.kind == JObject and permissions.len > 0:
      delta.permissionsChanged = true
  true

proc parseRosterDeltas*(communityChanges: JsonNode): seq[RosterDelta] =
  ## Roster deltas of a `communityChanges` array; changes without roster
  ## content are skipped.
  if communityChanges.isNil or communityChanges.kind != JArray:
    return
  for change in communityChanges.elems:
    var delta: RosterDelta
    if parseRosterDelta(change, delta) and not delta.isEmpty:
      result.add move(delta)
