{.used.}

import json, strutils, chronicles
import ../../../common/types
import link_preview, payment_request

include ../../../common/json_utils

from ../../../common/conversion import SystemTagMapping

const PARSED_TEXT_TYPE_PARAGRAPH* = "paragraph"
const PARSED_TEXT_TYPE_BLOCKQUOTE* = "blockquote"
const PARSED_TEXT_TYPE_CODEBLOCK* = "codeblock"

const PARSED_TEXT_CHILD_TYPE_CODE* = "code"
const PARSED_TEXT_CHILD_TYPE_EMPH* = "emph"
const PARSED_TEXT_CHILD_TYPE_STRONG* = "strong"
const PARSED_TEXT_CHILD_TYPE_STRONG_EMPH* = "strong-emph"
const PARSED_TEXT_CHILD_TYPE_MENTION* = "mention"
const PARSED_TEXT_CHILD_TYPE_STATUS_TAG* = "status-tag"
const PARSED_TEXT_CHILD_TYPE_DEL* = "del"
const PARSED_TEXT_CHILD_TYPE_LINK* = "link"

const PARSED_TEXT_OUTGOING_STATUS_SENDING*   = "sending"
const PARSED_TEXT_OUTGOING_STATUS_SENT*      = "sent"
const PARSED_TEXT_OUTGOING_STATUS_DELIVERED* = "delivered"
const PARSED_TEXT_OUTGOING_STATUS_EXPIRED* = "expired"
const PARSED_TEXT_OUTGOING_STATUS_FAILED_RESENDING* = "failedResending"

type ParsedText* = object
  `type`*: string
  literal*: string
  destination*: string
  children*: seq[ParsedText]

type DiscordMessageAttachment* = object
  id*: string
  fileUrl*: string
  fileName*: string
  localUrl*: string
  contentType*: string

type DiscordMessageAuthor* = object
  id*: string
  name*: string
  nickname*: string
  avatarUrl*: string
  localUrl*: string

type DiscordMessage* = object
  id*: string
  `type`*: string
  timestamp*: string
  timestampEdited*: string
  content*: string
  author*: DiscordMessageAuthor
  attachments*: seq[DiscordMessageAttachment]

type BridgeMessage* = object
  bridgeName*: string
  userName*: string
  userAvatar*: string
  userId*: string
  content*: string
  messageId*: string
  parentMessageId*: string

type QuotedMessage* = object
  `from`*: string
  text*: string
  parsedText*: seq[ParsedText]
  contentType*: ContentType
  deleted*: bool
  discordMessage*: DiscordMessage
  bridgeMessage*: BridgeMessage
  albumImages*: seq[string]
  albumImagesCount*: int

type Sticker* = object
  hash*: string
  url*: string
  pack*: int

type GapParameters* = object
  `from`*: int64
  to*: int64

type TransactionParameters* = object
  id*: string
  fromAddress*: string
  address*: string
  contract*: string
  value*: string
  transactionHash*: string
  commandState*: int
  signature*: string

type MessageDto* = object
  id*: string
  communityId*: string
  `from`*: string
  alias*: string
  seen*: bool
  outgoingStatus*: string
  quotedMessage*: QuotedMessage
  discordMessage*: DiscordMessage
  bridgeMessage*: BridgeMessage
  rtl*: bool
  parsedText*: seq[ParsedText]
  lineCount*: int
  text*: string
  chatId*: string
  localChatId*: string
  threadId*: string
  clock*: int64
  replace*: string
  responseTo*: string
  ensName*: string
  sticker*: Sticker
  image*: string
  albumId*: string
  albumImagesCount*: int
  gapParameters*: GapParameters
  timestamp*: int64
  contentType*: ContentType
  messageType*: int
  contactRequestState*: int
  links*: seq[string]
  linkPreviews*: seq[LinkPreview]
  editedAt*: int
  deleted*: bool
  deletedBy*: string
  deletedForMe*: bool
  pinnedBy*: string
  transactionParameters*: TransactionParameters
  mentioned*: bool
  replied*: bool
  paymentRequests*: seq[PaymentRequest]

proc toParsedText*(jsonObj: JsonNode): ParsedText =
  result = ParsedText()
  discard jsonObj.getProp("type", result.type)
  discard jsonObj.getProp("literal", result.literal)
  discard jsonObj.getProp("destination", result.destination)

  var childrenArr: JsonNode
  if(jsonObj.getProp("children", childrenArr) and childrenArr.kind == JArray):
    for childObj in childrenArr:
      result.children.add(toParsedText(childObj))

proc toDiscordMessageAuthor*(jsonObj: JsonNode): DiscordMessageAuthor =
  result = DiscordMessageAuthor()
  discard jsonObj.getProp("id", result.id)
  discard jsonObj.getProp("name", result.name)
  discard jsonObj.getProp("nickname", result.nickname)
  discard jsonObj.getProp("avatarUrl", result.avatarUrl)
  discard jsonObj.getProp("localUrl", result.localUrl)


proc toDiscordMessageAttachment*(jsonObj: JsonNode): DiscordMessageAttachment =
  result = DiscordMessageAttachment()
  discard jsonObj.getProp("id", result.id)
  discard jsonObj.getProp("url", result.fileUrl)
  discard jsonObj.getProp("localUrl", result.localUrl)
  discard jsonObj.getProp("fileName", result.fileName)
  discard jsonObj.getProp("contentType", result.contentType)

proc toDiscordMessage*(jsonObj: JsonNode): DiscordMessage =
  result = DiscordMessage()
  discard jsonObj.getProp("id", result.id)
  discard jsonObj.getProp("type", result.type)
  discard jsonObj.getProp("timestamp", result.timestamp)
  discard jsonObj.getProp("timestampEdited", result.timestampEdited)
  discard jsonObj.getProp("content", result.content)

  var discordMessageAuthorObj: JsonNode
  if(jsonObj.getProp("author", discordMessageAuthorObj)):
    result.author = toDiscordMessageAuthor(discordMessageAuthorObj)

  result.attachments = @[]
  var attachmentsArr: JsonNode
  if(jsonObj.getProp("attachments", attachmentsArr) and attachmentsArr.kind == JArray):
    for attachment in attachmentsArr:
      result.attachments.add(toDiscordMessageAttachment(attachment))

proc toBridgeMessage*(jsonObj: JsonNode): BridgeMessage =
  result = BridgeMessage()
  discard jsonObj.getProp("userName", result.userName)
  discard jsonObj.getProp("bridgeName", result.bridgeName)
  discard jsonObj.getProp("userAvatar", result.userAvatar)
  discard jsonObj.getProp("userID", result.userId)
  discard jsonObj.getProp("content", result.content)
  discard jsonObj.getProp("messageID", result.messageId)
  discard jsonObj.getProp("parentMessageID", result.parentMessageId)

proc toQuotedMessage*(jsonObj: JsonNode): QuotedMessage =
  result = QuotedMessage()
  var contentType: int
  discard jsonObj.getProp("from", result.`from`)
  discard jsonObj.getProp("text", result.text)
  discard jsonObj.getProp("contentType", contentType)
  result.contentType = toContentType(contentType)
  discard jsonObj.getProp("deleted", result.deleted)

  var parsedTextArr: JsonNode
  if(jsonObj.getProp("parsedText", parsedTextArr) and parsedTextArr.kind == JArray):
    for pTextObj in parsedTextArr:
      result.parsedText.add(toParsedText(pTextObj))

  var discordMessageObj: JsonNode
  if(jsonObj.getProp("discordMessage", discordMessageObj)):
    result.discordMessage = toDiscordMessage(discordMessageObj)

  var bridgeMessageObj: JsonNode
  if(jsonObj.getProp("bridgeMessage", bridgeMessageObj)):
    result.bridgeMessage = toBridgeMessage(bridgeMessageObj)

  var quotedImagesArr: JsonNode
  if jsonObj.getProp("albumImages", quotedImagesArr):
    for element in quotedImagesArr.getElems():
      if element.getStr() == "":
        continue
      result.albumImages.add(element.getStr())

  discard jsonObj.getProp("albumImagesCount", result.albumImagesCount)

proc toSticker*(jsonObj: JsonNode): Sticker =
  result = Sticker()
  discard jsonObj.getProp("hash", result.hash)
  discard jsonObj.getProp("pack", result.pack)
  discard jsonObj.getProp("url", result.url)

proc toGapParameters*(jsonObj: JsonNode): GapParameters =
  result = GapParameters()
  discard jsonObj.getProp("from", result.from)
  discard jsonObj.getProp("to", result.to)

proc toTransactionParameters*(jsonObj: JsonNode): TransactionParameters =
  result = TransactionParameters()
  discard jsonObj.getProp("id", result.id)
  discard jsonObj.getProp("from", result.fromAddress)
  discard jsonObj.getProp("address", result.address)
  discard jsonObj.getProp("contract", result.contract)
  discard jsonObj.getProp("value", result.value)
  discard jsonObj.getProp("transactionHash", result.transactionHash)
  discard jsonObj.getProp("commandState", result.commandState)
  discard jsonObj.getProp("signature", result.signature)

proc toMessageDto*(jsonObj: JsonNode): MessageDto =
  result = MessageDto()
  var contentType: int
  discard jsonObj.getProp("id", result.id)
  discard jsonObj.getProp("communityId", result.communityId)
  discard jsonObj.getProp("from", result.from)
  discard jsonObj.getProp("alias", result.alias)
  discard jsonObj.getProp("seen", result.seen)
  discard jsonObj.getProp("outgoingStatus", result.outgoingStatus)
  discard jsonObj.getProp("rtl", result.rtl)
  discard jsonObj.getProp("lineCount", result.lineCount)
  discard jsonObj.getProp("text", result.text)
  discard jsonObj.getProp("chatId", result.chatId)
  discard jsonObj.getProp("localChatId", result.localChatId)
  discard jsonObj.getProp("threadId", result.threadId)
  discard jsonObj.getProp("clock", result.clock)
  discard jsonObj.getProp("replace", result.replace)
  discard jsonObj.getProp("responseTo", result.responseTo)
  discard jsonObj.getProp("ensName", result.ensName)
  discard jsonObj.getProp("timestamp", result.timestamp)
  discard jsonObj.getProp("contentType", contentType)
  result.contentType = toContentType(contentType)
  discard jsonObj.getProp("messageType", result.messageType)
  discard jsonObj.getProp("contactRequestState", result.contactRequestState)
  discard jsonObj.getProp("image", result.image)
  discard jsonObj.getProp("albumId", result.albumId)
  discard jsonObj.getProp("albumImagesCount", result.albumImagesCount)
  discard jsonObj.getProp("editedAt", result.editedAt)
  discard jsonObj.getProp("deleted", result.deleted)
  discard jsonObj.getProp("deletedBy", result.deletedBy)
  if result.deleted and result.deletedBy == "":
    # The message was deleted by the sender itself
    result.deletedBy = result.`from`
  discard jsonObj.getProp("deletedForMe", result.deletedForMe)
  discard jsonObj.getProp("pinnedBy", result.pinnedBy)
  discard jsonObj.getProp("mentioned", result.mentioned)
  discard jsonObj.getProp("replied", result.replied)

  var quotedMessageObj: JsonNode
  if(jsonObj.getProp("quotedMessage", quotedMessageObj)):
    result.quotedMessage = toQuotedMessage(quotedMessageObj)

  var discordMessageObj: JsonNode
  if(jsonObj.getProp("discordMessage", discordMessageObj)):
    result.discordMessage = toDiscordMessage(discordMessageObj)

  var bridgeMessageObj: JsonNode
  if(jsonObj.getProp("bridgeMessage", bridgeMessageObj)):
    result.bridgeMessage = toBridgeMessage(bridgeMessageObj)

  var stickerObj: JsonNode
  if(jsonObj.getProp("sticker", stickerObj)):
    result.sticker = toSticker(stickerObj)

  var gapParametersObj: JsonNode
  if(jsonObj.getProp("gapParameters", gapParametersObj)):
    result.gapParameters = toGapParameters(gapParametersObj)

  var linksArr: JsonNode
  if(jsonObj.getProp("links", linksArr)):
    for link in linksArr:
      result.links.add(link.getStr)

  var linkPreviewsArr: JsonNode
  if jsonObj.getProp("linkPreviews", linkPreviewsArr):
    for element in linkPreviewsArr.getElems():
      result.linkPreviews.add(element.toLinkPreview(true))

  var statusLinkPreviewsArr: JsonNode
  if jsonObj.getProp("statusLinkPreviews", statusLinkPreviewsArr):
    for element in statusLinkPreviewsArr.getElems():
      result.linkPreviews.add(element.toLinkPreview(false))

  var paymentRequestsArr: JsonNode
  if jsonObj.getProp("paymentRequests", paymentRequestsArr):
    for element in paymentRequestsArr.getElems():
      result.paymentRequests.add(element.toPaymentRequest())

  var parsedTextArr: JsonNode
  if(jsonObj.getProp("parsedText", parsedTextArr) and parsedTextArr.kind == JArray):
    for pTextObj in parsedTextArr:
      result.parsedText.add(toParsedText(pTextObj))

  var transactionParametersObj: JsonNode
  if(jsonObj.getProp("commandParameters", transactionParametersObj)):
    result.transactionParameters = toTransactionParameters(transactionParametersObj)

proc containsContactMentions*(self: MessageDto): bool =
  for pText in self.parsedText:
    for child in pText.children:
      if (child.type == PARSED_TEXT_CHILD_TYPE_MENTION):
        return true
  return false

proc isPersonalMention*(self: MessageDto, publicKey: string): bool =
  for pText in self.parsedText:
    for child in pText.children:
      if (child.type == PARSED_TEXT_CHILD_TYPE_MENTION and child.literal.contains(publicKey)):
        return true
  return false

proc isGlobalMention*(self: MessageDto): bool =
  for pText in self.parsedText:
    for child in pText.children:
      if child.type == PARSED_TEXT_CHILD_TYPE_MENTION:
        for pair in SystemTagMapping:
          if child.literal.contains(pair[1]):
            return true

  return false

proc mentionedUsersPks*(self: MessageDto): seq[string] =
  for pText in self.parsedText:
    for child in pText.children:
      if (child.type == PARSED_TEXT_CHILD_TYPE_MENTION):
        result.add(child.literal)
