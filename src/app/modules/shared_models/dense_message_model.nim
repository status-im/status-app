## The dense message model: a `QAbstractListModel` with one row per stored
## message of the chat, where rows that have not been fetched are dummies the
## delegate renders as skeleton. All the sparse bookkeeping lives in
## `dense_message_store` (pure Nim, host-tested); this shell holds the payloads
## and turns the store's `Change` stream into model signals.
##
## It sits next to `message_model` rather than replacing it: the two are picked
## by a flag, and the wiring lands with the fetch scheduler.

import nimqml, json, tables, strutils

import model_utils
import dense_message_store
import message_item, message_transaction_parameters_item
from message_model import createMessageItemFromDtos

import ../../../app_service/service/message/dto/message
import ../../../app_service/service/contacts/dto/contact_details

export dense_message_store

const DUMMY_KEY_PREFIX* = "dummy:"

type
  ModelRole {.pure.} = enum
    Id = UserRole + 1
    Key
    Loaded
    PrevMsgTimestamp
    PrevMsgIndex
    PrevMsgSenderId
    PrevMsgContentType
    PrevMsgDeleted
    NextMsgIndex
    NextMsgTimestamp
    CommunityId
    ChatId
    ResponseToMessageWithId
    SenderId
    SenderDisplayName
    UsesDefaultName
    SenderOptionalName
    SenderIcon
    AmISender
    SenderIsAdded
    Seen
    OutgoingStatus
    MessageText
    UnparsedText
    MessageImage
    MessageContainsMentions # Actually we don't need to exposed this to qml since we only used it as an improved way to
                            # check whether we need to update mentioned contact name or not.
    Timestamp
    ContentType
    MessageType
    Sticker
    StickerPack
    GapFrom
    GapTo
    Pinned
    PinnedBy
    Reactions
    EditMode
    IsEdited
    Deleted
    DeletedBy
    DeletedByContactDisplayName
    DeletedByContactIcon
    Links
    LinkPreviewModel
    TransactionParameters
    MentionedUsersPks
    SenderTrustStatus
    SenderEnsVerified
    MessageAttachments
    ResendError
    Mentioned
    QuotedMessageFrom
    QuotedMessageText
    QuotedMessageParsedText
    QuotedMessageContentType
    QuotedMessageDeleted
    QuotedMessageAuthorName
    QuotedMessageAuthorDisplayName
    QuotedMessageAuthorThumbnailImage
    QuotedMessageAuthorEnsVerified
    QuotedMessageAuthorIsContact
    QuotedMessageAlbumMessageImages
    QuotedMessageAlbumImagesCount
    AlbumMessageImages
    AlbumImagesCount
    BridgeName
    PaymentRequestModel
    CompressedKey

const NEIGHBOUR_ROLES = @[
  ModelRole.PrevMsgTimestamp.int,
  ModelRole.PrevMsgIndex.int,
  ModelRole.PrevMsgSenderId.int,
  ModelRole.PrevMsgContentType.int,
  ModelRole.PrevMsgDeleted.int,
  ModelRole.NextMsgIndex.int,
  ModelRole.NextMsgTimestamp.int,
]

proc placeholderItem(): Item =
  ## One shared empty item backs every dummy row, so a dummy answers each role
  ## with a value of the right type instead of a hand-written zero per role.
  createMessageItemFromDtos(
    message = MessageDto(contentType: ContentType.Unknown),
    communityId = "",
    sender = ContactDetails(),
    isCurrentUser = false,
    renderedMessageText = "",
    clearText = "",
  )

proc toLoadedRow(item: Item): LoadedRow =
  LoadedRow(id: item.id, clock: item.clock)

QtObject:
  type
    DenseModel* = ref object of QAbstractListModel
      store: DenseStore
      payloads: Table[string, Item]
      placeholder: Item
      # Qt reads rowCount between beginInsertRows and endInsertRows, when the
      # store already holds the post-change count, so the shell keeps its own.
      announcedRowCount: int

  proc delete(self: DenseModel)
  proc setup(self: DenseModel)
  proc onBeforeChange(self: DenseModel, change: Change)
  proc onAfterChange(self: DenseModel, change: Change)

  proc newDenseModel*(loadedRowCap = DEFAULT_LOADED_ROW_CAP): DenseModel =
    new(result, delete)
    result.setup
    result.store = newDenseStore(loadedRowCap)
    result.payloads = initTable[string, Item]()
    result.placeholder = placeholderItem()
    result.announcedRowCount = 0
    let model = result
    result.store.beforeChange = proc(change: Change) = model.onBeforeChange(change)
    result.store.afterChange = proc(change: Change) = model.onAfterChange(change)

  proc delete(self: DenseModel) =
    self.QAbstractListModel.delete

  proc setup(self: DenseModel) =
    self.QAbstractListModel.setup

  proc countChanged(self: DenseModel) {.signal.}

  proc getCount(self: DenseModel): int {.slot.} =
    self.announcedRowCount
  QtProperty[int]count:
    read = getCount
    notify = countChanged

  proc getLoadedCount(self: DenseModel): int {.slot.} =
    self.store.loadedCount
  QtProperty[int]loadedCount:
    read = getLoadedCount
    notify = countChanged

  method rowCount*(self: DenseModel, index: QModelIndex = nil): int =
    return self.announcedRowCount

  method roleNames(self: DenseModel): Table[int, string] =
    {
      ModelRole.Key.int: "key",
      ModelRole.Loaded.int: "loaded",
      ModelRole.Id.int:"id",
      ModelRole.PrevMsgTimestamp.int: "prevMsgTimestamp",
      ModelRole.PrevMsgIndex.int:"prevMsgIndex",
      ModelRole.PrevMsgSenderId.int:"prevMsgSenderId",
      ModelRole.PrevMsgContentType.int:"prevMsgContentType",
      ModelRole.PrevMsgDeleted.int:"prevMsgDeleted",
      ModelRole.NextMsgIndex.int:"nextMsgIndex",
      ModelRole.NextMsgTimestamp.int:"nextMsgTimestamp",
      ModelRole.CommunityId.int:"communityId",
      ModelRole.ChatId.int:"chatId",
      ModelRole.ResponseToMessageWithId.int:"responseToMessageWithId",
      ModelRole.SenderId.int:"senderId",
      ModelRole.SenderDisplayName.int:"senderDisplayName",
      ModelRole.UsesDefaultName.int:"usesDefaultName",
      ModelRole.SenderOptionalName.int:"senderOptionalName",
      ModelRole.SenderIcon.int:"senderIcon",
      ModelRole.AmISender.int:"amISender",
      ModelRole.SenderIsAdded.int:"senderIsAdded",
      ModelRole.Seen.int:"seen",
      ModelRole.OutgoingStatus.int:"outgoingStatus",
      ModelRole.ResendError.int:"resendError",
      ModelRole.Mentioned.int:"mentioned",
      ModelRole.MessageText.int:"messageText",
      ModelRole.UnparsedText.int:"unparsedText",
      ModelRole.MessageImage.int:"messageImage",
      ModelRole.MessageContainsMentions.int:"messageContainsMentions",
      ModelRole.Timestamp.int:"timestamp",
      ModelRole.ContentType.int:"contentType",
      ModelRole.MessageType.int:"messageType",
      ModelRole.Sticker.int:"sticker",
      ModelRole.StickerPack.int:"stickerPack",
      ModelRole.GapFrom.int:"gapFrom",
      ModelRole.GapTo.int:"gapTo",
      ModelRole.Pinned.int:"pinned",
      ModelRole.PinnedBy.int:"pinnedBy",
      ModelRole.Reactions.int:"reactions",
      ModelRole.EditMode.int: "editMode",
      ModelRole.IsEdited.int: "isEdited",
      ModelRole.Deleted.int: "deleted",
      ModelRole.DeletedBy.int: "deletedBy",
      ModelRole.DeletedByContactDisplayName.int: "deletedByContactDisplayName",
      ModelRole.DeletedByContactIcon.int: "deletedByContactIcon",
      ModelRole.Links.int: "links",
      ModelRole.LinkPreviewModel.int: "linkPreviewModel",
      ModelRole.TransactionParameters.int: "transactionParameters",
      ModelRole.MentionedUsersPks.int: "mentionedUsersPks",
      ModelRole.SenderTrustStatus.int: "senderTrustStatus",
      ModelRole.SenderEnsVerified.int: "senderEnsVerified",
      ModelRole.MessageAttachments.int: "messageAttachments",
      ModelRole.QuotedMessageFrom.int: "quotedMessageFrom",
      ModelRole.QuotedMessageText.int: "quotedMessageText",
      ModelRole.QuotedMessageParsedText.int: "quotedMessageParsedText",
      ModelRole.QuotedMessageContentType.int: "quotedMessageContentType",
      ModelRole.QuotedMessageDeleted.int: "quotedMessageDeleted",
      ModelRole.QuotedMessageAuthorName.int: "quotedMessageAuthorName",
      ModelRole.QuotedMessageAuthorDisplayName.int: "quotedMessageAuthorDisplayName",
      ModelRole.QuotedMessageAuthorThumbnailImage.int: "quotedMessageAuthorThumbnailImage",
      ModelRole.QuotedMessageAuthorEnsVerified.int: "quotedMessageAuthorEnsVerified",
      ModelRole.QuotedMessageAuthorIsContact.int: "quotedMessageAuthorIsContact",
      ModelRole.QuotedMessageAlbumMessageImages.int: "quotedMessageAlbumMessageImages",
      ModelRole.QuotedMessageAlbumImagesCount.int: "quotedMessageAlbumImagesCount",
      ModelRole.AlbumMessageImages.int: "albumMessageImages",
      ModelRole.AlbumImagesCount.int: "albumImagesCount",
      ModelRole.BridgeName.int: "bridgeName",
      ModelRole.PaymentRequestModel.int: "paymentRequestModel",
      ModelRole.CompressedKey.int: "compressedKey",
    }.toTable

  proc itemAt(self: DenseModel, row: int): Item =
    if not self.store.isLoaded(row):
      return self.placeholder
    let id = self.store.rowAt(row).id
    self.payloads.withValue(id, hit):
      return hit[]
    return self.placeholder

  proc neighbourItem(self: DenseModel, neighbourRow: int): Item =
    if neighbourRow == -1:
      return self.placeholder
    return self.itemAt(neighbourRow)

  method data(self: DenseModel, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.announcedRowCount, role, ModelRole)

    let row = index.row
    let loaded = self.store.isLoaded(row)
    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.Loaded:
      return newQVariant(loaded)
    of ModelRole.Key:
      # a dummy's key is positional and must never anchor anything: window
      # records anchor on loaded rows' message ids only
      if loaded:
        return newQVariant(self.store.rowAt(row).id)
      return newQVariant(DUMMY_KEY_PREFIX & $self.store.indexToRank(row))
    of ModelRole.PrevMsgIndex:
      return newQVariant(self.store.olderNeighbourIndex(row))
    of ModelRole.NextMsgIndex:
      return newQVariant(self.store.newerNeighbourIndex(row))
    of ModelRole.PrevMsgTimestamp:
      return newQVariant(self.neighbourItem(self.store.olderNeighbourIndex(row)).timestamp)
    of ModelRole.PrevMsgSenderId:
      return newQVariant(self.neighbourItem(self.store.olderNeighbourIndex(row)).senderId)
    of ModelRole.PrevMsgContentType:
      return newQVariant(self.neighbourItem(self.store.olderNeighbourIndex(row)).contentType.int)
    of ModelRole.PrevMsgDeleted:
      return newQVariant(self.neighbourItem(self.store.olderNeighbourIndex(row)).deleted)
    of ModelRole.NextMsgTimestamp:
      return newQVariant(self.neighbourItem(self.store.newerNeighbourIndex(row)).timestamp)
    else:
      discard

    let item = self.itemAt(row)

    case enumRole:
    of ModelRole.Id:
      result = newQVariant(item.id)
    of ModelRole.CommunityId:
      result = newQVariant(item.communityId)
    of ModelRole.ChatId:
      result = newQVariant(item.chatId)
    of ModelRole.ResponseToMessageWithId:
      result = newQVariant(item.responseToMessageWithId)
    of ModelRole.SenderId:
      result = newQVariant(item.senderId)
    of ModelRole.SenderDisplayName:
      result = newQVariant(item.senderDisplayName)
    of ModelRole.UsesDefaultName:
      result = newQVariant(item.senderUsesDefaultName)
    of ModelRole.SenderTrustStatus:
      result = newQVariant(item.senderTrustStatus.int)
    of ModelRole.SenderOptionalName:
      result = newQVariant(item.senderOptionalName)
    of ModelRole.SenderIcon:
      result = newQVariant(item.senderIcon)
    of ModelRole.AmISender:
      result = newQVariant(item.amISender)
    of ModelRole.SenderIsAdded:
      result = newQVariant(item.senderIsAdded)
    of ModelRole.Seen:
      result = newQVariant(item.seen)
    of ModelRole.OutgoingStatus:
      result = newQVariant(item.outgoingStatus)
    of ModelRole.ResendError:
      result = newQVariant(item.resendError)
    of ModelRole.Mentioned:
      result = newQVariant(item.mentioned)
    of ModelRole.QuotedMessageFrom:
      result = newQVariant(item.quotedMessageFrom)
    of ModelRole.QuotedMessageText:
      result = newQVariant(item.quotedMessageText)
    of ModelRole.QuotedMessageParsedText:
      result = newQVariant(item.quotedMessageParsedText)
    of ModelRole.QuotedMessageContentType:
      result = newQVariant(item.quotedMessageContentType.int)
    of ModelRole.QuotedMessageDeleted:
      result = newQVariant(item.quotedMessageDeleted)
    of ModelRole.QuotedMessageAuthorName:
      result = newQVariant(item.quotedMessageAuthorDetails.dto.name)
    of ModelRole.QuotedMessageAuthorDisplayName:
      result = newQVariant(item.quotedMessageAuthorDisplayName)
    of ModelRole.QuotedMessageAuthorThumbnailImage:
      result = newQVariant(item.quotedMessageAuthorAvatar)
    of ModelRole.QuotedMessageAuthorEnsVerified:
      result = newQVariant(item.quotedMessageAuthorDetails.dto.ensVerified)
    of ModelRole.QuotedMessageAuthorIsContact:
      result = newQVariant(item.quotedMessageAuthorDetails.dto.isContact())
    of ModelRole.QuotedMessageAlbumMessageImages:
      result = newQVariant(item.quotedMessageAlbumMessageImages.join(" "))
    of ModelRole.QuotedMessageAlbumImagesCount:
      result = newQVariant(item.quotedMessageAlbumImagesCount)
    of ModelRole.MessageText:
      result = newQVariant(item.messageText)
    of ModelRole.UnparsedText:
      result = newQVariant(item.unparsedText)
    of ModelRole.MessageImage:
      result = newQVariant(item.messageImage)
    of ModelRole.MessageContainsMentions:
      result = newQVariant(item.messageContainsMentions)
    of ModelRole.Timestamp:
      result = newQVariant(item.timestamp)
    of ModelRole.ContentType:
      result = newQVariant(item.contentType.int)
    of ModelRole.MessageType:
      result = newQVariant(item.messageType)
    of ModelRole.Sticker:
      result = newQVariant(item.sticker)
    of ModelRole.StickerPack:
      result = newQVariant(item.stickerPack)
    of ModelRole.GapFrom:
      result = newQVariant(item.gapFrom)
    of ModelRole.GapTo:
      result = newQVariant(item.gapTo)
    of ModelRole.Pinned:
      result = newQVariant(item.pinned)
    of ModelRole.PinnedBy:
      result = newQVariant(item.pinnedBy)
    of ModelRole.Reactions:
      result = newQVariant(item.reactionsModel)
    of ModelRole.EditMode:
      result = newQVariant(item.editMode)
    of ModelRole.IsEdited:
      result = newQVariant(item.isEdited)
    of ModelRole.Deleted:
      result = newQVariant(item.deleted)
    of ModelRole.DeletedBy:
      result = newQVariant(item.deletedBy)
    of ModelRole.DeletedByContactDisplayName:
      result = newQVariant(item.deletedByContactDetails.dto.userDefaultDisplayName())
    of ModelRole.DeletedByContactIcon:
      result = newQVariant(item.deletedByContactDetails.dto.image.thumbnail)
    of ModelRole.Links:
      result = newQVariant(item.links.join(" "))
    of ModelRole.LinkPreviewModel:
      result = newQVariant(item.linkPreviewModel)
    of ModelRole.TransactionParameters:
      result = newQVariant($(%*{
        "id": item.transactionParameters.id,
        "fromAddress": item.transactionParameters.fromAddress,
        "address": item.transactionParameters.address,
        "contract": item.transactionParameters.contract,
        "value": item.transactionParameters.value,
        "transactionHash": item.transactionParameters.transactionHash,
        "commandState": item.transactionParameters.commandState,
        "signature": item.transactionParameters.signature
      }))
    of ModelRole.MentionedUsersPks:
      result = newQVariant(item.mentionedUsersPks.join(" "))
    of ModelRole.SenderEnsVerified:
      result = newQVariant(item.senderEnsVerified)
    of ModelRole.MessageAttachments:
      result = newQVariant(item.messageAttachments.join(" "))
    of ModelRole.AlbumMessageImages:
      result = newQVariant(item.albumMessageImages.join(" "))
    of ModelRole.AlbumImagesCount:
      result = newQVariant(item.albumImagesCount)
    of ModelRole.BridgeName:
      result = newQVariant(item.bridgeName)
    of ModelRole.PaymentRequestModel:
      result = newQVariant(item.paymentRequestModel)
    of ModelRole.CompressedKey:
      result = newQVariant(item.compressedKey)
    else:
      discard

  proc notifyRowsChanged(self: DenseModel, first, last: int, roles: seq[int]) =
    if first < 0 or last < first or last >= self.announcedRowCount:
      return
    let topLeft = self.createIndex(first, 0, nil)
    let bottomRight = self.createIndex(last, 0, nil)
    defer:
      topLeft.delete
      bottomRight.delete
    self.dataChanged(topLeft, bottomRight, roles)

  proc onBeforeChange(self: DenseModel, change: Change) =
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete
    case change.kind:
    of ckReset:
      self.beginResetModel()
    of ckRowsInserted:
      self.beginInsertRows(parentModelIndex, change.first, change.last)
    of ckRowsRemoved:
      self.beginRemoveRows(parentModelIndex, change.first, change.last)
    of ckRowsChanged, ckNeighbourRolesChanged:
      discard

  proc onAfterChange(self: DenseModel, change: Change) =
    case change.kind:
    of ckReset:
      self.announcedRowCount = self.store.rowCount
      self.endResetModel()
      self.countChanged()
    of ckRowsInserted:
      self.announcedRowCount = self.store.rowCount
      self.endInsertRows()
      self.countChanged()
    of ckRowsRemoved:
      self.announcedRowCount = self.store.rowCount
      self.endRemoveRows()
      self.countChanged()
    of ckRowsChanged:
      # a fill, an eviction or a re-anchor: the row count never moves, so this
      # is the whole of it — no insert, no remove, no geometry churn
      self.notifyRowsChanged(change.first, change.last, @[])
      self.countChanged()
    of ckNeighbourRolesChanged:
      self.notifyRowsChanged(change.first, change.last, NEIGHBOUR_ROLES)

    for id in change.droppedIds:
      self.payloads.del(id)

  proc dropOrphanedPayloads(self: DenseModel) =
    ## Rows the store refused or released without naming them (a page that lost
    ## a conflict, say) would otherwise keep their payload alive forever.
    var orphans: seq[string] = @[]
    for id in self.payloads.keys:
      if not self.store.contains(id):
        orphans.add(id)
    for id in orphans:
      self.payloads.del(id)

  proc registerPayloads(self: DenseModel, items: seq[Item]) =
    for item in items:
      self.payloads[item.id] = item

  # ------------------------------------------------------------- public API

  proc resetToChat*(self: DenseModel, totalCount: int) =
    self.payloads.clear()
    self.store.reset(totalCount)

  proc totalCount*(self: DenseModel): int =
    self.store.totalCount

  proc holes*(self: DenseModel): seq[Hole] =
    self.store.holes()

  proc setWindow*(self: DenseModel, firstIndex, lastIndex: int, margin = 0) =
    self.store.setWindow(firstIndex, lastIndex, margin)

  proc setLoadedRowCap*(self: DenseModel, cap: int) =
    self.store.setLoadedRowCap(cap)

  proc applyPage*(self: DenseModel, items: seq[Item], firstRank: int, totalCount = -1) =
    ## `items` is newest-first, exactly as status-go returns a page, and
    ## `items[i]` has rank `firstRank - i`.
    self.registerPayloads(items)
    var rows: seq[LoadedRow] = @[]
    for item in items:
      rows.add(item.toLoadedRow)
    self.store.applyPage(rows, firstRank, totalCount)
    self.dropOrphanedPayloads()

  proc addLiveMessages*(self: DenseModel, items: seq[Item], totalCount = -1) =
    self.registerPayloads(items)
    var rows: seq[LoadedRow] = @[]
    for item in items:
      rows.add(item.toLoadedRow)
    self.store.appendLive(rows, totalCount)
    self.dropOrphanedPayloads()

  proc addBackfilledMessage*(self: DenseModel, item: Item, totalCount = -1) =
    self.registerPayloads(@[item])
    self.store.insertBackfilled(item.toLoadedRow, totalCount)
    self.dropOrphanedPayloads()

  proc setTotalCount*(self: DenseModel, totalCount: int) =
    self.store.setTotalCount(totalCount)

  proc messageDeleted*(self: DenseModel, messageId: string, clock: int64, totalCount = -1) =
    ## The message left the chat's storage. A loaded row goes; a message that
    ## falls inside a hole shrinks that hole.
    self.store.removeMessage(messageId, clock, totalCount)
    self.dropOrphanedPayloads()

  proc findIndexForMessageId*(self: DenseModel, messageId: string): int =
    self.store.indexOfId(messageId)

  proc getItemWithMessageId*(self: DenseModel, messageId: string): Item =
    self.payloads.withValue(messageId, hit):
      return hit[]
    return nil

  proc getMessageByIdAsJson*(self: DenseModel, messageId: string): JsonNode =
    let item = self.getItemWithMessageId(messageId)
    if item.isNil:
      return
    item.toJsonNode()

  proc getMessageByIndexAsJson*(self: DenseModel, index: int): JsonNode =
    if not self.store.isLoaded(index):
      return
    self.itemAt(index).toJsonNode()

  # Granular updates address a loaded row by id. A row that is not loaded has
  # no payload to update and no delegate to notify, so it is silently skipped:
  # whatever the update carried arrives with the row when it is fetched.
  template updateLoaded(self: DenseModel, messageId: string, body: untyped) =
    let row {.inject.} = self.store.indexOfId(messageId)
    if row != -1:
      self.payloads.withValue(messageId, hitPtr):
        let item {.inject.} = hitPtr[]
        body

  proc emitRoles(self: DenseModel, row: int, roles: seq[int]) =
    self.notifyRowsChanged(row, row, roles)

  proc setOutgoingStatus*(self: DenseModel, messageId: string, status: string) =
    self.updateLoaded(messageId):
      if item.outgoingStatus != status:
        item.outgoingStatus = status
        self.emitRoles(row, @[ModelRole.OutgoingStatus.int])

  proc setResendError*(self: DenseModel, messageId: string, error: string) =
    self.updateLoaded(messageId):
      item.resendError = error
      self.emitRoles(row, @[ModelRole.ResendError.int])

  proc addReaction*(self: DenseModel, messageId, emoji: string, didIReactWithThisEmoji: bool,
      userPublicKey, userDisplayName, reactionId: string) =
    self.updateLoaded(messageId):
      item.addReaction(emoji, didIReactWithThisEmoji, userPublicKey, userDisplayName, reactionId)

  proc removeReaction*(self: DenseModel, messageId, emoji, reactionId: string,
      didIRemoveThisReaction: bool) =
    self.updateLoaded(messageId):
      item.removeReaction(emoji, reactionId, didIRemoveThisReaction)

  proc updateReactionId*(self: DenseModel, messageId, emoji, userPublicKey,
      reactionId: string): bool =
    result = false
    self.updateLoaded(messageId):
      result = item.updateReactionId(emoji, userPublicKey, reactionId)

  proc pinUnpinMessage*(self: DenseModel, messageId: string, pinned: bool, pinnedBy: string) =
    self.updateLoaded(messageId):
      if item.pinned != pinned or item.pinnedBy != pinnedBy:
        item.pinned = pinned
        item.pinnedBy = pinnedBy
        self.emitRoles(row, @[ModelRole.Pinned.int, ModelRole.PinnedBy.int])

  proc setEditMode*(self: DenseModel, messageId: string, editMode: bool) =
    self.updateLoaded(messageId):
      if item.editMode != editMode:
        item.editMode = editMode
        self.emitRoles(row, @[ModelRole.EditMode.int])

  proc updateEditedMsg*(self: DenseModel, messageId, updatedMsg, updatedRawMsg: string,
      updatedParsedText: seq[ParsedText], mentioned, messageContainsMentions: bool,
      links, mentionedUsersPks: seq[string]) =
    self.updateLoaded(messageId):
      item.messageText = updatedMsg
      item.unparsedText = updatedRawMsg
      item.parsedText = updatedParsedText
      item.mentioned = mentioned
      item.messageContainsMentions = messageContainsMentions
      item.isEdited = true
      item.links = links
      item.mentionedUsersPks = mentionedUsersPks
      self.emitRoles(row, @[
        ModelRole.MessageText.int,
        ModelRole.UnparsedText.int,
        ModelRole.Mentioned.int,
        ModelRole.MessageContainsMentions.int,
        ModelRole.IsEdited.int,
        ModelRole.Links.int,
        ModelRole.MentionedUsersPks.int,
      ])

  proc markMessageDeletedInPlace*(self: DenseModel, messageId, deletedBy: string,
      deletedByContactDetails: ContactDetails) =
    ## The `deleted = 1` case: the row stays and still counts, it just loses its
    ## content.
    self.updateLoaded(messageId):
      item.messageText = ""
      item.unparsedText = ""
      item.deleted = true
      item.deletedBy = deletedBy
      item.deletedByContactDetails = deletedByContactDetails
      self.emitRoles(row, @[
        ModelRole.MessageText.int,
        ModelRole.UnparsedText.int,
        ModelRole.Deleted.int,
        ModelRole.DeletedBy.int,
        ModelRole.DeletedByContactDisplayName.int,
        ModelRole.DeletedByContactIcon.int,
      ])
      self.notifyRowsChanged(row - 1, row - 1, NEIGHBOUR_ROLES)

  proc markAsSeen*(self: DenseModel, messageIds: seq[string]) =
    for messageId in messageIds:
      self.updateLoaded(messageId):
        if not item.seen:
          item.seen = true
          self.emitRoles(row, @[ModelRole.Seen.int])

  proc updateMediaServerPort*(self: DenseModel, port: int) =
    for id, item in self.payloads:
      if not item.updateMediaServerPort(port):
        continue
      let row = self.store.indexOfId(id)
      if row == -1:
        continue
      self.notifyRowsChanged(row, row, @[
        ModelRole.SenderIcon.int,
        ModelRole.MessageImage.int,
        ModelRole.Sticker.int,
        ModelRole.DeletedByContactIcon.int,
        ModelRole.QuotedMessageAuthorThumbnailImage.int,
        ModelRole.QuotedMessageAlbumMessageImages.int,
        ModelRole.AlbumMessageImages.int,
        ModelRole.MessageAttachments.int,
      ])
