## One community's member roster: a slim entry per member plus a key -> row
## table. Filled on demand by one insert; every delta after that is a single
## insert, remove or dataChanged. data() never calls the backend: it reads the
## entry, the contacts cache (through `RosterLookups.contact`) and the online
## status table. Rows keep the snapshot order; views sort and filter in proxies.

import nimqml, std/[tables, json]

import app_service/common/types
import app_service/service/community/dto/roster
import user_item
import contacts_utils
import model_utils

export roster, user_item.ContactRequest

when defined(QT_MODEL_SPY):
  import ../shared/qt_model_spy

type
  ## Contacts-cache fields a member row shows; default for anyone the cache
  ## does not hold.
  RosterContact* = object
    localNickname*: string
    displayName*: string
    ensName*: string
    ensVerified*: bool
    alias*: string
    icon*: string
    isContact*: bool
    isBlocked*: bool
    trustStatus*: TrustStatus
    contactRequest*: ContactRequest

  RosterLookups* = object
    myPubKey*: string
    contact*: proc(pubKey: string): RosterContact
    onlineStatus*: proc(pubKey: string): OnlineStatus
    contactImageUrl*: proc(pubKey: string, clock: uint64): string

  ModelRole {.pure.} = enum
    PubKey = UserRole + 1
    CompressedPubKey
    IsCurrentUser
    DisplayName
    PreferredDisplayName
    UsesDefaultName
    EnsName
    IsEnsVerified
    LocalNickname
    Alias
    Icon
    ColorId
    OnlineStatus
    IsContact
    IsVerified
    IsUntrustworthy
    TrustStatus
    IsBlocked
    ContactRequest
    MemberRole
    Joined
    RequestToJoinId
    RequestToJoinLoading
    DeclineRequestToJoinLoading
    AirdropAddress
    MembershipRequestState

const
  # roles whose value comes from the contacts cache
  ContactRoles = [ModelRole.DisplayName, ModelRole.PreferredDisplayName,
    ModelRole.UsesDefaultName, ModelRole.EnsName, ModelRole.IsEnsVerified,
    ModelRole.LocalNickname, ModelRole.Alias, ModelRole.Icon, ModelRole.IsContact,
    ModelRole.IsVerified, ModelRole.IsUntrustworthy, ModelRole.TrustStatus,
    ModelRole.IsBlocked, ModelRole.ContactRequest]

QtObject:
  type
    CommunityRosterModel* = ref object of QAbstractListModel
      lookups: RosterLookups
      myKey: RawPubKey
      hasMyKey: bool
      members: seq[RosterMember]
      rows: Table[RawPubKey, int]
      channels: Table[string, Table[RawPubKey, ChannelRole]]
      # admin-only overlays, set by their owners; absent = Accepted / ""
      membershipStates: Table[RawPubKey, MembershipRequestState]
      airdropAddresses: Table[RawPubKey, string]
      loaded: bool
      channelMembersChangedHandler: proc(chatId: string)

  proc delete(self: CommunityRosterModel)
  proc setup(self: CommunityRosterModel)
  proc newCommunityRosterModel*(lookups: RosterLookups): CommunityRosterModel =
    new(result, delete)
    result.lookups = lookups
    result.hasMyKey = parseRawPubKey(lookups.myPubKey, result.myKey)
    result.setup

  proc countChanged*(self: CommunityRosterModel) {.signal.}
  proc loadedChanged*(self: CommunityRosterModel) {.signal.}
  proc channelMembersChanged*(self: CommunityRosterModel, chatId: string) {.signal.}

  proc getCount*(self: CommunityRosterModel): int {.slot.} =
    self.members.len

  QtProperty[int] count:
    read = getCount
    notify = countChanged

  proc isLoaded*(self: CommunityRosterModel): bool {.slot.} =
    self.loaded

  QtProperty[bool] loaded:
    read = isLoaded
    notify = loadedChanged

  method rowCount*(self: CommunityRosterModel, index: QModelIndex = nil): int =
    self.members.len

  method roleNames(self: CommunityRosterModel): Table[int, string] =
    {
      ModelRole.PubKey.int: "pubKey",
      ModelRole.CompressedPubKey.int: "compressedPubKey",
      ModelRole.IsCurrentUser.int: "isCurrentUser",
      ModelRole.DisplayName.int: "displayName",
      ModelRole.PreferredDisplayName.int: "preferredDisplayName",
      ModelRole.UsesDefaultName.int: "usesDefaultName",
      ModelRole.EnsName.int: "ensName",
      ModelRole.IsEnsVerified.int: "isEnsVerified",
      ModelRole.LocalNickname.int: "localNickname",
      ModelRole.Alias.int: "alias",
      ModelRole.Icon.int: "icon",
      ModelRole.ColorId.int: "colorId",
      ModelRole.OnlineStatus.int: "onlineStatus",
      ModelRole.IsContact.int: "isContact",
      ModelRole.IsVerified.int: "isVerified",
      ModelRole.IsUntrustworthy.int: "isUntrustworthy",
      ModelRole.TrustStatus.int: "trustStatus",
      ModelRole.IsBlocked.int: "isBlocked",
      ModelRole.ContactRequest.int: "contactRequest",
      ModelRole.MemberRole.int: "memberRole",
      ModelRole.Joined.int: "joined",
      ModelRole.RequestToJoinId.int: "requestToJoinId",
      ModelRole.RequestToJoinLoading.int: "requestToJoinLoading",
      ModelRole.DeclineRequestToJoinLoading.int: "declineRequestToJoinLoading",
      ModelRole.AirdropAddress.int: "airdropAddress",
      ModelRole.MembershipRequestState.int: "membershipRequestState",
    }.toTable

  method data(self: CommunityRosterModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.members.len, role, ModelRole)

    let enumRole = role.ModelRole
    template member: untyped = self.members[index.row]

    case enumRole
    of ModelRole.CompressedPubKey:
      return newQVariant(compressedPubKey(member.key))
    of ModelRole.IsCurrentUser:
      return newQVariant(self.hasMyKey and member.key == self.myKey)
    of ModelRole.ColorId:
      return newQVariant(member.colorId)
    of ModelRole.MemberRole:
      return newQVariant(member.role.int)
    of ModelRole.Joined:
      return newQVariant(true)
    of ModelRole.RequestToJoinId:
      return newQVariant("")
    of ModelRole.RequestToJoinLoading, ModelRole.DeclineRequestToJoinLoading:
      return newQVariant(false)
    of ModelRole.AirdropAddress:
      return newQVariant(self.airdropAddresses.getOrDefault(member.key))
    of ModelRole.MembershipRequestState:
      return newQVariant(self.membershipStates.getOrDefault(member.key,
        MembershipRequestState.Accepted).int)
    else:
      discard

    let pubKey = toPubKeyHex(member.key)
    case enumRole
    of ModelRole.PubKey:
      return newQVariant(pubKey)
    of ModelRole.OnlineStatus:
      return newQVariant(self.lookups.onlineStatus(pubKey).int)
    else:
      discard

    # a name the contacts cache holds is fresher than the entry's
    let contact = self.lookups.contact(pubKey)
    let isCurrentUser = self.hasMyKey and member.key == self.myKey
    let displayName = if contact.displayName.len > 0: contact.displayName else: member.displayName
    let fromContactEns = contact.ensName.len > 0
    let ensName = if fromContactEns: contact.ensName else: member.ensName
    let ensVerified = if fromContactEns: contact.ensVerified else: member.ensVerified
    let alias = if contact.alias.len > 0: contact.alias else: member.alias
    let effectiveEnsName = if ensVerified: ensName else: ""

    case enumRole
    of ModelRole.DisplayName:
      newQVariant(displayName)
    of ModelRole.PreferredDisplayName:
      newQVariant(resolvePreferredDisplayName(contact.localNickname, effectiveEnsName,
        displayName, alias))
    of ModelRole.UsesDefaultName:
      newQVariant(resolveUsesDefaultName(contact.localNickname, effectiveEnsName, displayName))
    of ModelRole.EnsName:
      newQVariant(ensName)
    of ModelRole.IsEnsVerified:
      newQVariant(ensVerified)
    of ModelRole.LocalNickname:
      newQVariant(contact.localNickname)
    of ModelRole.Alias:
      newQVariant(alias)
    of ModelRole.Icon:
      if contact.icon.len > 0 or self.lookups.contactImageUrl.isNil:
        newQVariant(contact.icon)
      else:
        newQVariant(self.lookups.contactImageUrl(pubKey, member.thumbnailImageClock))
    of ModelRole.IsContact:
      newQVariant(contact.isContact)
    of ModelRole.IsVerified:
      newQVariant(not isCurrentUser and contact.trustStatus == TrustStatus.Trusted)
    of ModelRole.IsUntrustworthy:
      newQVariant(not isCurrentUser and contact.trustStatus == TrustStatus.Untrustworthy)
    of ModelRole.TrustStatus:
      newQVariant(contact.trustStatus.int)
    of ModelRole.IsBlocked:
      newQVariant(contact.isBlocked)
    of ModelRole.ContactRequest:
      newQVariant(contact.contactRequest.int)
    else:
      nil

  proc notifyRow(self: CommunityRosterModel, row: int, roles: openArray[ModelRole]) =
    var intRoles = newSeqOfCap[int](roles.len)
    for role in roles:
      intRoles.add role.int
    when defined(QT_MODEL_SPY):
      recordDataChanged(row, row, intRoles)
    let modelIndex = self.createIndex(row, 0, nil)
    defer: modelIndex.delete
    self.dataChanged(modelIndex, modelIndex, intRoles)

  proc notifyRowAll(self: CommunityRosterModel, row: int) =
    when defined(QT_MODEL_SPY):
      recordDataChanged(row, row, @[])
    let modelIndex = self.createIndex(row, 0, nil)
    defer: modelIndex.delete
    self.dataChanged(modelIndex, modelIndex)

  proc rowOf(self: CommunityRosterModel, pubKey: string): int =
    var key: RawPubKey
    if not parseRawPubKey(pubKey, key):
      return -1
    self.rows.getOrDefault(key, -1)

  proc hasMember*(self: CommunityRosterModel, pubKey: string): bool {.slot.} =
    self.rowOf(pubKey) >= 0

  proc setLoaded(self: CommunityRosterModel, loaded: bool) =
    if self.loaded == loaded:
      return
    self.loaded = loaded
    self.loadedChanged()

  proc emitChannelMembersChanged(self: CommunityRosterModel, chatId: string) =
    self.channelMembersChanged(chatId)
    if not self.channelMembersChangedHandler.isNil:
      self.channelMembersChangedHandler(chatId)

  proc clear*(self: CommunityRosterModel) =
    ## Drops the roster (idle or background release).
    var droppedChannels: seq[string]
    for chatId in self.channels.keys:
      droppedChannels.add chatId
    self.channels.clear()
    self.membershipStates.clear()
    self.airdropAddresses.clear()
    if self.members.len > 0:
      let parentIndex = newQModelIndex()
      defer: parentIndex.delete
      when defined(QT_MODEL_SPY):
        recordBeginRemoveRows(0, self.members.len - 1)
      self.beginRemoveRows(parentIndex, 0, self.members.len - 1)
      self.members = @[]
      self.rows.clear()
      self.endRemoveRows()
      when defined(QT_MODEL_SPY):
        recordEndRemoveRows()
      self.countChanged()
    for chatId in droppedChannels:
      self.emitChannelMembersChanged(chatId)
    self.setLoaded(false)

  proc fill*(self: CommunityRosterModel, snapshot: sink RosterSnapshot) =
    if self.members.len > 0 or self.channels.len > 0:
      self.clear()
    for chatId, channelMembers in snapshot.channels.pairs:
      var roles = initTable[RawPubKey, ChannelRole](channelMembers.len)
      for member in channelMembers:
        roles[member.key] = member.role
      self.channels[chatId] = roles
    if snapshot.members.len > 0:
      var rows = initTable[RawPubKey, int](snapshot.members.len)
      var members = newSeqOfCap[RosterMember](snapshot.members.len)
      for member in snapshot.members.mitems:
        if rows.hasKey(member.key):
          continue
        rows[member.key] = members.len
        members.add move(member)
      let parentIndex = newQModelIndex()
      defer: parentIndex.delete
      when defined(QT_MODEL_SPY):
        recordBeginInsertRows(0, members.len - 1)
      self.beginInsertRows(parentIndex, 0, members.len - 1)
      self.members = move(members)
      self.rows = move(rows)
      self.endInsertRows()
      when defined(QT_MODEL_SPY):
        recordEndInsertRows()
      self.countChanged()
    for chatId in self.channels.keys:
      self.emitChannelMembersChanged(chatId)
    self.setLoaded(true)

  proc upsert(self: CommunityRosterModel, member: RosterMember) =
    let row = self.rows.getOrDefault(member.key, -1)
    if row >= 0:
      self.members[row] = member
      self.notifyRowAll(row)
      return
    let parentIndex = newQModelIndex()
    defer: parentIndex.delete
    let newRow = self.members.len
    when defined(QT_MODEL_SPY):
      recordBeginInsertRows(newRow, newRow)
    self.beginInsertRows(parentIndex, newRow, newRow)
    self.members.add member
    self.rows[member.key] = newRow
    self.endInsertRows()
    when defined(QT_MODEL_SPY):
      recordEndInsertRows()
    self.countChanged()

  proc remove(self: CommunityRosterModel, key: RawPubKey) =
    let row = self.rows.getOrDefault(key, -1)
    if row < 0:
      return
    let parentIndex = newQModelIndex()
    defer: parentIndex.delete
    when defined(QT_MODEL_SPY):
      recordBeginRemoveRows(row, row)
    self.beginRemoveRows(parentIndex, row, row)
    self.members.delete(row)
    self.rows.del(key)
    for i in row ..< self.members.len:
      self.rows[self.members[i].key] = i
    self.membershipStates.del(key)
    self.airdropAddresses.del(key)
    self.endRemoveRows()
    when defined(QT_MODEL_SPY):
      recordEndRemoveRows()
    self.countChanged()

  proc applyChannelDelta(self: CommunityRosterModel, delta: ChannelMembersDelta) =
    # a channel absent from the snapshot that gains members has just been gated;
    # one left without members stays gated (it shows nobody) until a new snapshot
    if not self.channels.hasKey(delta.chatId) and delta.added.len == 0:
      return
    var roles = self.channels.getOrDefault(delta.chatId)
    for key in delta.removed:
      roles.del(key)
    for member in delta.added:
      roles[member.key] = member.role
    for member in delta.modified:
      if roles.hasKey(member.key):
        roles[member.key] = member.role
    self.channels[delta.chatId] = roles
    self.emitChannelMembersChanged(delta.chatId)

  proc applyDelta*(self: CommunityRosterModel, delta: RosterDelta) =
    for key in delta.removed:
      self.remove(key)
    for member in delta.added:
      self.upsert(member)
    for member in delta.modified:
      self.upsert(member)
    for channel in delta.channels:
      self.applyChannelDelta(channel)

  proc iconsChanged*(self: CommunityRosterModel) =
    ## Media server restarted on a new port: every avatar URL changed.
    if self.members.len == 0:
      return
    let roles = @[ModelRole.Icon.int]
    when defined(QT_MODEL_SPY):
      recordDataChanged(0, self.members.len - 1, roles)
    let first = self.createIndex(0, 0, nil)
    let last = self.createIndex(self.members.len - 1, 0, nil)
    defer:
      first.delete
      last.delete
    self.dataChanged(first, last, roles)

  proc contactChanged*(self: CommunityRosterModel, pubKey: string) =
    let row = self.rowOf(pubKey)
    if row >= 0:
      self.notifyRow(row, ContactRoles)

  proc onlineStatusChanged*(self: CommunityRosterModel, pubKey: string) =
    let row = self.rowOf(pubKey)
    if row >= 0:
      self.notifyRow(row, [ModelRole.OnlineStatus])

  proc setMembershipState*(self: CommunityRosterModel, pubKey: string, state: MembershipRequestState) =
    let row = self.rowOf(pubKey)
    if row < 0:
      return
    let key = self.members[row].key
    if self.membershipStates.getOrDefault(key, MembershipRequestState.Accepted) == state:
      return
    if state == MembershipRequestState.Accepted:
      self.membershipStates.del(key)
    else:
      self.membershipStates[key] = state
    self.notifyRow(row, [ModelRole.MembershipRequestState])

  proc setAirdropAddress*(self: CommunityRosterModel, pubKey: string, address: string) =
    let row = self.rowOf(pubKey)
    if row < 0:
      return
    let key = self.members[row].key
    if self.airdropAddresses.getOrDefault(key) == address:
      return
    if address.len == 0:
      self.airdropAddresses.del(key)
    else:
      self.airdropAddresses[key] = address
    self.notifyRow(row, [ModelRole.AirdropAddress])

  proc onChannelMembersChanged*(self: CommunityRosterModel, handler: proc(chatId: string)) =
    ## Nim-side listener (the future key-set filter); QML uses the signal.
    self.channelMembersChangedHandler = handler

  proc isGatedChannel*(self: CommunityRosterModel, chatId: string): bool {.slot.} =
    self.channels.hasKey(chatId)

  proc channelMembers*(self: CommunityRosterModel, chatId: string): seq[string] =
    self.channels.withValue(chatId, members):
      for key in members[].keys:
        result.add toPubKeyHex(key)

  proc channelRole*(self: CommunityRosterModel, chatId: string, pubKey: string): ChannelRole =
    var key: RawPubKey
    if not parseRawPubKey(pubKey, key):
      return ChannelRole.Poster
    self.channels.withValue(chatId, members):
      return members[].getOrDefault(key, ChannelRole.Poster)

  proc getChannelMemberKeys*(self: CommunityRosterModel, chatId: string): string {.slot.} =
    ## JSON array of the member keys of a token-gated channel.
    $(%self.channelMembers(chatId))

  proc delete(self: CommunityRosterModel) =
    self.QAbstractListModel.delete

  proc setup(self: CommunityRosterModel) =
    self.QAbstractListModel.setup
