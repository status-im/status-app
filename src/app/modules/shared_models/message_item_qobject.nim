import nimqml, std/wrapnils, strutils
import ./message_item

QtObject:
  type MessageItem* = ref object of QObject
    messageItem*: message_item.Item

  proc setup(self: MessageItem)
  proc delete*(self: MessageItem)
  proc newMessageItem*(message: message_item.Item): MessageItem =
    new(result, delete)
    result.setup
    result.messageItem = message

  proc `$`*(self: MessageItem): string =
    result = $self.messageItem

  proc setMessageItem*(self: MessageItem, messageItem: message_item.Item) =
    self.messageItem = messageItem

  proc id*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.id
  QtProperty[string] id:
    read = id

  proc responseToMessageWithId*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.responseToMessageWithId
  QtProperty[string] responseToMessageWithId:
    read = responseToMessageWithId

  proc quotedMessageFrom*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.quotedMessageFrom
  QtProperty[string] quotedMessageFrom:
    read = quotedMessageFrom

  proc quotedMessageText*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.quotedMessageText
  QtProperty[string] quotedMessageText:
    read = quotedMessageText

  proc quotedMessageContentType*(self: MessageItem): int {.slot.} = result = ?.self.messageItem.quotedMessageContentType.int
  QtProperty[int] quotedMessageContentType:
    read = quotedMessageContentType

  proc quotedMessageDeleted*(self: MessageItem): bool {.slot.} = result = ?.self.messageItem.quotedMessageDeleted
  QtProperty[bool] quotedMessageDeleted:
    read = quotedMessageDeleted

  proc quotedMessageAuthorDisplayName*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.quotedMessageAuthorDisplayName
  QtProperty[string] quotedMessageAuthorDisplayName:
    read = quotedMessageAuthorDisplayName

  proc quotedMessageAuthorAvatar*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.quotedMessageAuthorAvatar
  QtProperty[string] quotedMessageAuthorAvatar:
    read = quotedMessageAuthorAvatar

  proc quotedMessageAlbumMessageImages*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.quotedMessageAlbumMessageImages.join(" ")
  QtProperty[string] quotedMessageAlbumMessageImages:
    read = quotedMessageAlbumMessageImages

  proc quotedMessageAlbumImagesCount*(self: MessageItem): int {.slot.} = result = ?.self.messageItem.quotedMessageAlbumImagesCount
  QtProperty[int] quotedMessageAlbumImagesCount:
    read = quotedMessageAlbumImagesCount

  proc senderId*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.senderId
  QtProperty[string] senderId:
    read = senderId

  proc pinnedBy*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.pinnedBy
  QtProperty[string] pinnedBy:
    read = pinnedBy

  proc senderTrustStatus*(self: MessageItem): int {.slot.} = 
    let trustStatus = ?.self.messageItem.senderTrustStatus
    return trustStatus.int

  QtProperty[int] senderTrustStatus:
    read = senderTrustStatus

  proc senderDisplayName*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.senderDisplayName
  QtProperty[string] senderDisplayName:
    read = senderDisplayName

  proc senderOptionalName*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.senderOptionalName
  QtProperty[string] senderOptionalName:
    read = senderOptionalName

  proc senderEnsVerified*(self: MessageItem): bool {.slot.} = result = ?.self.messageItem.senderEnsVerified
  QtProperty[bool] senderEnsVerified:
    read = senderEnsVerified

  proc amISender*(self: MessageItem): bool {.slot.} = result = ?.self.messageItem.amISender
  QtProperty[bool] amISender:
    read = amISender

  proc mentioned*(self: MessageItem): bool {.slot.} = result = ?.self.messageItem.mentioned
  QtProperty[bool] mentioned:
    read = mentioned

  proc senderIcon*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.senderIcon
  QtProperty[string] senderIcon:
    read = senderIcon

  proc seen*(self: MessageItem): bool {.slot.} = result = ?.self.messageItem.seen
  QtProperty[bool] seen:
    read = seen

  proc outgoingStatus*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.outgoingStatus
  QtProperty[string] outgoingStatus:
    read = outgoingStatus

  proc unparsedText*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.unparsedText
  QtProperty[string] unparsedText:
    read = unparsedText

  proc messageImage*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.messageImage
  QtProperty[string] messageImage:
    read = messageImage

  proc sticker*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.sticker
  QtProperty[string] sticker:
    read = sticker

  proc stickerPack*(self: MessageItem): int {.slot.} = result = ?.self.messageItem.stickerPack
  QtProperty[int] stickerPack:
    read = stickerPack

  # Convert to int
  # proc gapFrom*(self: MessageItem): int64 {.slot.} = result = ?.self.messageItem.gapFrom
  # QtProperty[int64] gapFrom:
  #   read = gapFrom

  # proc gapTo*(self: MessageItem): int64 {.slot.} = result = ?.self.messageItem.gapTo
  # QtProperty[int64] gapTo:
  #   read = gapTo

  # proc timestamp*(self: MessageItem): int64 {.slot.} = result = ?.self.messageItem.timestamp
  # QtProperty[int64] timestamp:
  #   read = timestamp

  proc contentType*(self: MessageItem): int {.slot.} =
    if (self.messageItem.isNil): return 0
    result = self.messageItem.contentType.int
  QtProperty[int] contentType:
    read = contentType

  proc messageType*(self: MessageItem): int {.slot.} = result = ?.self.messageItem.messageType
  QtProperty[int] messageType:
    read = messageType

  proc contactRequestState*(self: MessageItem): int {.slot.} = result = ?.self.messageItem.contactRequestState
  QtProperty[int] contactRequestState:
    read = contactRequestState

  # TODO find a way to pass reactions since they are not basic types (might need to be a Model)
  # proc reactions*(self: MessageItem): int {.slot.} = result = ?.self.messageItem.reactions
  # QtProperty[int] reactions:
  #   read = reactions

  # proc reactionIds*(self: MessageItem): int {.slot.} = result = ?.self.messageItem.reactionIds
  # QtProperty[int] reactionIds:
  #   read = reactionIds

  proc pinned*(self: MessageItem): bool {.slot.} = result = ?.self.messageItem.pinned
  QtProperty[bool] pinned:
    read = pinned

  proc editMode*(self: MessageItem): bool {.slot.} = result = ?.self.messageItem.editMode
  QtProperty[bool] editMode:
    read = editMode

  proc isEdited*(self: MessageItem): bool {.slot.} = result = ?.self.messageItem.isEdited
  QtProperty[bool] isEdited:
    read = isEdited

  # this is not the greatest approach, but aligns with the rest of the code
  proc communityId*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.communityId
  QtProperty[string] communityId:
    read = communityId

  proc reactionsModel*(self: MessageItem): QVariant {.slot.} = result = newQVariant(?.self.messageItem.reactionsModel)
  QtProperty[QVariant] reactionsModel:
    read = reactionsModel
  
  proc albumId*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.albumId
  QtProperty[string] albumId:
    read = albumId

  proc albumMessageImages*(self: MessageItem): string {.slot.} = result = ?.self.messageItem.albumMessageImages.join(" ")
  QtProperty[string] albumMessageImages:
    read = albumMessageImages

  proc albumImagesCount*(self: MessageItem): int {.slot.} = result = ?.self.messageItem.albumImagesCount
  QtProperty[int] albumImagesCount:
    read = albumImagesCount

  proc setup(self: MessageItem) =
    self.QObject.setup

  proc delete*(self: MessageItem) =
    self.QObject.delete

