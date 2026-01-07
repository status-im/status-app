import nimqml, tables, json, sets, algorithm, sequtils, strutils, std/strformat, sugar

import message_item, message_transaction_parameters_item, contacts_utils

import ../../../app_service/service/message/dto/message
import ../../../app_service/service/contacts/dto/contact_details

type
  ModelRole {.pure.} = enum
    Id = UserRole + 1
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

QtObject:
  type
    Model* = ref object of QAbstractListModel
      items*: seq[Item]
      firstUnseenMessageId: string

  proc delete(self: Model)
  proc setup(self: Model)

  proc newModel*(): Model =
    new(result, delete)
    result.setup
    result.firstUnseenMessageId = ""

  proc delete(self: Model) =
    self.QAbstractListModel.delete

  proc setup(self: Model) =
    self.QAbstractListModel.setup

  proc `$`*(self: Model): string =
    result = "MessageModel:\n"
    for i in 0 ..< self.items.len:
      result &= fmt"""
      [{i}]:({$self.items[i]})
      """

  proc resetNewMessagesMarker*(self: Model)

  proc countChanged(self: Model) {.signal.}
  proc getCount(self: Model): int {.slot.} =
    self.items.len
  QtProperty[int]count:
    read = getCount
    notify = countChanged

  method rowCount*(self: Model, index: QModelIndex = nil): int =
    return self.items.len

  method roleNames(self: Model): Table[int, string] =
    {
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

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    if (not index.isValid):
      return

    if (index.row < 0 or index.row >= self.items.len):
      return

    let item = self.items[index.row]
    let enumRole = role.ModelRole

    case enumRole:
    of ModelRole.Id:
      result = newQVariant(item.id)
    of ModelRole.PrevMsgTimestamp:
      if (index.row + 1 < self.items.len):
        let prevItem = self.items[index.row + 1]
        result = newQVariant(prevItem.timestamp)
      else:
        result = newQVariant(0)
    of ModelRole.PrevMsgSenderId:
      if (index.row + 1 < self.items.len):
        let prevItem = self.items[index.row + 1]
        result = newQVariant(prevItem.senderId)
      else:
        result = newQVariant("")
    of ModelRole.PrevMsgContentType:
      if (index.row + 1 < self.items.len):
        let prevItem = self.items[index.row + 1]
        result = newQVariant(prevItem.contentType.int)
      else:
        result = newQVariant(ContentType.Unknown.int)
    of ModelRole.PrevMsgDeleted:
      if (index.row + 1 < self.items.len):
        let prevItem = self.items[index.row + 1]
        result = newQVariant(prevItem.deleted)
      else:
        result = newQVariant(false)
    of ModelRole.PrevMsgIndex:
      result = newQVariant(index.row + 1)
    of ModelRole.NextMsgIndex:
      result = newQVariant(index.row - 1)
    of ModelRole.NextMsgTimestamp:
      if (index.row - 1 >= 0 and index.row - 1 < self.items.len):
        let nextItem = self.items[index.row - 1]
        result = newQVariant(nextItem.timestamp)
      else:
        result = newQVariant(0)
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

  proc updateItemAtIndex(self: Model, index: int) =
    let ind = self.createIndex(index, 0, nil)
    defer: ind.delete
    self.dataChanged(ind, ind)

  proc findIndexForMessageId*(self: Model, messageId: string): int =
    result = -1
    if messageId.len == 0:
      return
    for i in 0 ..< self.items.len:
      let item = self.items[i]
      if(item.id == messageId):
        result = i
        return
      elif item.albumId != "":
        for j in 0 ..< item.albumMessageIds.len:
          if(item.albumMessageIds[j] == messageId):
            result = i
            return

  proc findIdsOfTheMessagesWhichRespondedToMessageWithId*(self: Model, messageId: string): seq[string] =
    for i in 0 ..< self.items.len:
      if(self.items[i].responseToMessageWithId == messageId):
        result.add(self.items[i].id)

  # sort predicate - most recent clocks first, break ties by message id
  proc isGreaterThan(lhsItem, rhsItem: Item): bool =
    return lhsItem.clock > rhsItem.clock or
           (lhsItem.clock == rhsItem.clock and lhsItem.id > rhsItem.id)

  proc insertItems(self: Model, position: int, items: seq[Item]) =
    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    # Update replied to messages if there are
    # We update replies before adding, since we do not need to update the new items, they should already be up to date
    for i in 0 ..< self.items.len:
      var oldItem = self.items[i]
      if oldItem.responseToMessageWithId == "" or oldItem.quotedMessageFrom != "":
        continue
      for newItem in items:
        if oldItem.responseToMessageWithId == newItem.id:
          oldItem.quotedMessageFrom = newItem.senderId
          oldItem.quotedMessageAuthorDisplayName = newItem.senderDisplayName
          oldItem.quotedMessageAuthorAvatar = newItem.senderIcon
          oldItem.quotedMessageParsedText = newItem.messageText
          oldItem.quotedMessageText = newItem.unparsedText
          oldItem.quotedMessageContentType = newItem.contentType
          let index = self.createIndex(i, 0, nil)
          defer: index.delete
          self.dataChanged(index, index, @[
            ModelRole.QuotedMessageFrom.int,
            ModelRole.QuotedMessageAuthorDisplayName.int,
            ModelRole.QuotedMessageAuthorThumbnailImage.int,
            ModelRole.QuotedMessageText.int,
            ModelRole.QuotedMessageParsedText.int,
            ModelRole.QuotedMessageContentType.int,
          ])


    self.beginInsertRows(parentModelIndex, position, position + items.len - 1)
    self.items.insert(items, position)
    self.endInsertRows()

    if position > 0:
      self.updateItemAtIndex(position - 1)
    if position + items.len - 1 < self.items.len:
      self.updateItemAtIndex(position + items.len)
    self.countChanged()

  proc filterExistingItems(self: Model, items: seq[Item]): seq[Item] =
    let existingItems = toHashSet(self.items.map(x => x.id))
    return items.filter(item => not existingItems.contains(item.id))

  proc insertItemsBasedOnClock*(self: Model, items: seq[Item]) =
    # remove existing items and sort by most recent
    let sortCmp = proc(lhs, rhs: Item): int =
      return if isGreaterThan(lhs, rhs): -1 else: 1
    let newItems = sorted(self.filterExistingItems(items), sortCmp)

    # bulk insert algorithm, "two-pointer" technique
    var currentIdx = 0
    var newIdx = 0
    var numRows = 0

    while currentIdx < self.items.len and newIdx < newItems.len:
      let newItem = newItems[newIdx]
      let currentItem = self.items[currentIdx]
      if isGreaterThan(newItem, currentItem):
        newIdx += 1
        numRows += 1
      else:
        if numRows > 0:
          self.insertItems(currentIdx, newItems[newIdx-numRows..newIdx-1])
          numRows = 0
        currentIdx += 1

    if numRows > 0:
      self.insertItems(currentIdx, newItems[newIdx-numRows..newIdx-1])
    if newIdx < newItems.len:
      self.insertItems(currentIdx, newItems[newIdx..newItems.len-1])

  proc insertItemBasedOnClock*(self: Model, item: Item) =
    self.insertItemsBasedOnClock(@[item])

  # Replied message was deleted
  proc updateMessagesWhenQuotedMessageDeleted(self: Model, messageId: string) =
    for i in 0 ..< self.items.len:
      if(self.items[i].responseToMessageWithId == messageId):
        let ind = self.createIndex(i, 0, nil)
        defer: ind.delete
        var item = self.items[i]
        item.quotedMessageText = ""
        item.quotedMessageParsedText = ""
        item.quotedMessageDeleted = true
        self.dataChanged(ind, ind, @[
          ModelRole.QuotedMessageText.int,
          ModelRole.QuotedMessageParsedText.int,
          ModelRole.QuotedMessageDeleted.int,
        ])

  proc removeItem*(self: Model, messageId: string) =
    let ind = self.findIndexForMessageId(messageId)
    if(ind == -1):
      return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    self.beginRemoveRows(parentModelIndex, ind, ind)
    self.items.delete(ind)
    self.endRemoveRows()

    self.resetNewMessagesMarker()

    if ind > 0 and ind < self.items.len:
      self.updateItemAtIndex(ind - 1)
    if ind + 1 < self.items.len:
      self.updateItemAtIndex(ind + 1)

    self.countChanged()
    self.updateMessagesWhenQuotedMessageDeleted(messageId)

  proc messageRemoved*(self: Model, messageId: string, deletedBy: string, deletedByContactDetails: ContactDetails) =
    let i = self.findIndexForMessageId(messageId)
    if(i == -1):
      return

    let ind = self.createIndex(i, 0, nil)
    defer: ind.delete

    var item = self.items[i]
    item.messageText = ""
    item.unparsedText = ""
    item.deleted = true
    item.deletedBy = deletedBy
    item.deletedByContactDetails = deletedByContactDetails
    self.dataChanged(ind, ind, @[
      ModelRole.MessageText.int,
      ModelRole.UnparsedText.int,
      ModelRole.Deleted.int,
      ModelRole.DeletedBy.int,
      ModelRole.DeletedByContactDisplayName.int,
      ModelRole.DeletedByContactIcon.int,
    ])

    self.updateMessagesWhenQuotedMessageDeleted(messageId)

  proc getLastItemFrom*(self: Model, pubkey: string): Item =
    # last item == first time since we process messages in reverse order
    for i in 0 ..< self.items.len:
      if self.items[i].senderId == pubkey:
        return self.items[i]


  proc getItemWithMessageId*(self: Model, messageId: string): Item =
    let ind = self.findIndexForMessageId(messageId)
    if(ind == -1):
      return

    return self.items[ind]

  proc setOutgoingStatus(self: Model, messageId: string, status: string) =
    let ind = self.findIndexForMessageId(messageId)
    if(ind == -1):
      return
    if self.items[ind].outgoingStatus == PARSED_TEXT_OUTGOING_STATUS_DELIVERED:
      return
    self.items[ind].outgoingStatus = status
    let index = self.createIndex(ind, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[ModelRole.OutgoingStatus.int])

  proc itemSending*(self: Model, messageId: string) =
    self.setOutgoingStatus(messageId, PARSED_TEXT_OUTGOING_STATUS_SENDING)

  proc itemSent*(self: Model, messageId: string) =
    self.setOutgoingStatus(messageId, PARSED_TEXT_OUTGOING_STATUS_SENT)

  proc itemDelivered*(self: Model, messageId: string) =
    self.setOutgoingStatus(messageId, PARSED_TEXT_OUTGOING_STATUS_DELIVERED)

  proc itemExpired*(self: Model, messageId: string) =
    self.setOutgoingStatus(messageId, PARSED_TEXT_OUTGOING_STATUS_EXPIRED)

  proc itemFailedResending*(self: Model, messageId: string, error: string) =
    let ind = self.findIndexForMessageId(messageId)
    if(ind == -1):
      return
    self.items[ind].resendError = error
    let index = self.createIndex(ind, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[ModelRole.ResendError.int])

  proc addReaction*(self: Model, messageId: string, emoji: string, didIReactWithThisEmoji: bool,
    userPublicKey: string, userDisplayName: string, reactionId: string) =
    let ind = self.findIndexForMessageId(messageId)
    if(ind == -1):
      return

    self.items[ind].addReaction(emoji, didIReactWithThisEmoji, userPublicKey, userDisplayName, reactionId)

  proc removeReaction*(self: Model, messageId: string, emoji: string, reactionId: string, didIRemoveThisReaction: bool) =
    let ind = self.findIndexForMessageId(messageId)
    if(ind == -1):
      return

    self.items[ind].removeReaction(emoji, reactionId, didIRemoveThisReaction)

    let index = self.createIndex(ind, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[ModelRole.Reactions.int])

  proc pinUnpinMessage*(self: Model, messageId: string, pinned: bool, pinnedBy: string) =
    let ind = self.findIndexForMessageId(messageId)
    if ind == -1:
      return

    if self.items[ind].pinned == pinned:
      return

    self.items[ind].pinned = pinned
    self.items[ind].pinnedBy = pinnedBy

    let index = self.createIndex(ind, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[ModelRole.Pinned.int, ModelRole.PinnedBy.int])

  proc getMessageByIdAsJson*(self: Model, messageId: string): JsonNode =
    for it in self.items:
      if(it.id == messageId):
        return it.toJsonNode()

  proc getMessageByIndexAsJson*(self: Model, index: int): JsonNode =
    if(index < 0 or index >= self.items.len):
      return
    self.items[index].toJsonNode()

  iterator items*(self: Model): Item =
    for i in 0 ..< self.items.len:
      yield self.items[i]

  iterator modelContactUpdateIterator*(self: Model, contactId: string): Item =
    for i in 0 ..< self.items.len:
      yield self.items[i]

      var roles: seq[int]
      if(self.items[i].senderId == contactId):
        roles = @[ModelRole.SenderDisplayName.int,
          ModelRole.SenderOptionalName.int,
          ModelRole.UsesDefaultName.int,
          ModelRole.SenderIcon.int,
          ModelRole.SenderIsAdded.int,
          ModelRole.SenderTrustStatus.int,
          ModelRole.SenderEnsVerified.int]
      if(self.items[i].pinnedBy == contactId):
        roles.add(ModelRole.PinnedBy.int)
      if(self.items[i].messageContainsMentions):
        roles.add(@[ModelRole.MessageText.int, ModelRole.UnparsedText.int, ModelRole.MessageContainsMentions.int])

      if (self.items[i].quotedMessageFrom == contactId):
        roles.add(@[ModelRole.QuotedMessageAuthorName.int,
          ModelRole.QuotedMessageAuthorDisplayName.int,
          ModelRole.QuotedMessageAuthorThumbnailImage.int,
          ModelRole.QuotedMessageAuthorEnsVerified.int,
          ModelRole.QuotedMessageAuthorIsContact.int])

      if(roles.len > 0):
        let index = self.createIndex(i, 0, nil)
        defer: index.delete
        self.dataChanged(index, index, roles)

  proc setEditModeOn*(self: Model, messageId: string)  =
    let ind = self.findIndexForMessageId(messageId)
    if(ind == -1):
      return

    self.items[ind].editMode = true

    let index = self.createIndex(ind, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[ModelRole.EditMode.int])

  proc setEditModeOff*(self: Model, messageId: string)  =
    let ind = self.findIndexForMessageId(messageId)
    if(ind == -1):
      return

    self.items[ind].editMode = false

    let index = self.createIndex(ind, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[ModelRole.EditMode.int])

  proc updateEditedMsg*(
      self: Model,
      messageId: string,
      updatedMsg: string,
      updatedRawMsg: string,
      updatedParsedText: seq[ParsedText],
      contentType: ContentType,
      mentioned: bool,
      messageContainsMentions: bool,
      links: seq[string],
      mentionedUsersPks: seq[string]
      ) =
    let ind = self.findIndexForMessageId(messageId)
    if(ind == -1):
      return

    self.items[ind].messageText = updatedMsg
    self.items[ind].mentioned = mentioned
    self.items[ind].messageContainsMentions = messageContainsMentions
    self.items[ind].isEdited = true
    self.items[ind].links = links
    self.items[ind].mentionedUsersPks = mentionedUsersPks
    self.items[ind].parsedText = updatedParsedText

    let index = self.createIndex(ind, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[
      ModelRole.MessageText.int,
      ModelRole.UnparsedText.int,
      ModelRole.Mentioned.int,
      ModelRole.MessageContainsMentions.int,
      ModelRole.IsEdited.int,
      ModelRole.Links.int,
      ModelRole.MentionedUsersPks.int
      ])

    # Update replied to messages if there are
    for i in 0 ..< self.items.len:
      if(self.items[i].responseToMessageWithId == messageId):
        self.items[i].quotedMessageParsedText = updatedMsg
        self.items[i].quotedMessageText = updatedRawMsg
        self.items[i].quotedMessageContentType = contentType
        let index = self.createIndex(i, 0, nil)
        defer: index.delete
        self.dataChanged(index, index, @[
          ModelRole.QuotedMessageText.int,
          ModelRole.QuotedMessageParsedText.int,
          ModelRole.QuotedMessageContentType.int,
        ])

  proc clear*(self: Model) =
    self.beginResetModel()
    self.items = @[]
    self.endResetModel()
    self.countChanged()

  proc refreshItemWithId*(self: Model, messageId: string) =
    let ind = self.findIndexForMessageId(messageId)
    if(ind == -1):
      return
    self.updateItemAtIndex(ind)

  proc setFirstUnseenMessageId*(self: Model, messageId: string) =
    self.firstUnseenMessageId = messageId

  proc getFirstUnseenMessageId*(self: Model): string =
    self.firstUnseenMessageId

  proc newMessagesMarkerIndex*(self: Model): int =
    result = -1
    for i in countdown(self.items.len - 1, 0):
      if self.items[i].contentType == ContentType.NewMessagesMarker:
        return i

  proc removeNewMessagesMarker(self: Model) =
    let index = self.newMessagesMarkerIndex()
    if index == -1:
      return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    self.beginRemoveRows(parentModelIndex, index, index)
    self.items.delete(index)
    self.endRemoveRows()
    self.countChanged()

  proc resetNewMessagesMarker*(self: Model) =
    self.removeNewMessagesMarker()
    let messageId = self.firstUnseenMessageId
    if messageId == "":
      return

    let index = self.findIndexForMessageId(messageId)
    if index == -1:
      return

    let position = index + 1

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    self.beginInsertRows(parentModelIndex, position, position)
    self.items.insert(initNewMessagesMarkerItem(self.items[index].clock, self.items[index].timestamp), position)
    self.endInsertRows()
    self.countChanged()

  proc getNewMessagesCount*(self: Model): int {.slot.} =
    max(0, self.newMessagesMarkerIndex())
  QtProperty[int]newMessagesCount:
    read = getNewMessagesCount
    notify = countChanged

  proc markAllAsSeen*(self: Model) =
    for i in 0 ..< self.items.len:
      let item = self.items[i]
      if not item.seen:
        item.seen = true
        let index = self.createIndex(i, 0, nil)
        defer: index.delete
        self.dataChanged(index, index, @[ModelRole.Seen.int])

  proc setMessageMarker*(self: Model, messageId: string) =
    self.firstUnseenMessageId = messageId
    self.resetNewMessagesMarker()

  proc markMessageAsUnread*(self: Model, messageId: string) =
    self.setMessageMarker(messageId)

    for i in 0 ..< self.items.len:
      let item = self.items[i]

      if item.id == messageId and item.seen:
        item.seen = false
        let index = self.createIndex(i, 0, nil)
        defer: index.delete
        self.dataChanged(index, index, @[ModelRole.Seen.int])
        break


  proc markAsSeen*(self: Model, messages: seq[string]) =
    var messagesSet = toHashSet(messages)

    for i in 0 ..< self.items.len:
      let currentItemID = self.items[i].id

      if messagesSet.contains(currentItemID):
        self.items[i].seen = true
        let index = self.createIndex(i, 0, nil)
        defer: index.delete
        self.dataChanged(index, index, @[ModelRole.Seen.int])
        messagesSet.excl(currentItemID)

      if messagesSet.len == 0:
        return

  proc getFirstUnseenMentionMessageId*(self: Model): string =
    result = ""
    for i in countdown(self.items.len - 1, 0):
      if not self.items[i].seen and self.items[i].mentioned:
        return self.items[i].id

  proc updateAlbumIfExists*(self: Model, albumId: string, messageImage: string, messageId: string): bool =
    for i in 0 ..< self.items.len:
      let item = self.items[i]
      if item.albumId == albumId:
        # Check if message already in album
        for j in 0 ..< item.albumMessageIds.len:
          if item.albumMessageIds[j] == messageId:
            return true
        var albumImages = item.albumMessageImages
        var albumMessagesIds = item.albumMessageIds
        albumMessagesIds.add(messageId)
        albumImages.add(messageImage)
        item.albumMessageImages = albumImages
        item.albumMessageIds = albumMessagesIds

        let index = self.createIndex(i, 0, nil)
        defer: index.delete
        self.dataChanged(index, index, @[ModelRole.AlbumMessageImages.int])
        return true
    return false

  proc createMessageItemFromDtos*(
      message: MessageDto,
      communityId: string,
      sender: ContactDetails,
      isCurrentUser: bool,
      renderedMessageText: string,
      clearText: string,
      albumImages: seq[string] = @[],
      albumMessageIds: seq[string] = @[],
      deletedByContactDetails: ContactDetails = ContactDetails(),
      quotedMessageAuthorDetails: ContactDetails = ContactDetails(),
      quotedRenderedMessageText: string = "",
      transactionContract: string = "",
      transactionValue: string = "",
    ): Item =
    var albumImagesFinal = albumImages
    if albumImagesFinal.len == 0:
      albumImagesFinal = if (len(message.albumId) == 0): @[] else: @[message.image]

    var albumMessageIdsFinal = albumMessageIds
    if albumMessageIdsFinal.len == 0:
      albumMessageIdsFinal = if (len(message.albumId) == 0): @[] else: @[message.id]

    return message_item.initMessageItem(
      message.id,
      communityId,
      message.chatId,
      message.responseTo,
      message.`from`,
      sender.defaultDisplayName,
      sender.optionalName,
      senderUsesDefaultName = resolveUsesDefaultName(sender.dto.localNickname, sender.dto.name, sender.dto.displayName),
      sender.icon,
      (isCurrentUser and message.contentType != ContentType.DiscordMessage),
      sender.dto.added,
      message.outgoingStatus,
      renderedMessageText,
      clearText,
      message.parsedText,
      message.image,
      message.containsContactMentions(),
      message.seen,
      timestamp = message.timestamp,
      clock = message.clock,
      message.contentType,
      message.messageType,
      message.contactRequestState,
      sticker = message.sticker.url,
      message.sticker.pack,
      message.links,
      message.linkPreviews,
      newTransactionParametersItem(message.transactionParameters.id,
        message.transactionParameters.fromAddress,
        message.transactionParameters.address,
        transactionContract,
        transactionValue,
        message.transactionParameters.transactionHash,
        message.transactionParameters.commandState,
        message.transactionParameters.signature),
      message.mentionedUsersPks(),
      sender.dto.trustStatus,
      sender.dto.ensVerified,
      message.discordMessage,
      resendError = "",
      message.deleted,
      message.deletedBy,
      deletedByContactDetails,
      message.pinnedBy,
      message.mentioned,
      message.quotedMessage.`from`,
      message.quotedMessage.text,
      quotedRenderedMessageText,
      message.quotedMessage.contentType,
      message.quotedMessage.deleted,
      message.quotedMessage.discordMessage,
      quotedMessageAuthorDetails,
      message.quotedMessage.albumImages,
      message.quotedMessage.albumImagesCount,
      message.albumId,
      albumImagesFinal,
      albumMessageIdsFinal,
      message.albumImagesCount,
      message.bridgeMessage,
      message.quotedMessage.bridgeMessage,
      message.paymentRequests,
    )
