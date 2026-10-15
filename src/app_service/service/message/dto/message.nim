{.used.}

import json, strutils, chronicles
import ../../../common/types
import link_preview, payment_request

include ../../../common/json_utils


const PARSED_TEXT_TYPE_PARAGRAPH = "paragraph"
const PARSED_TEXT_CHILD_TYPE_MENTION = "mention"
const PARSED_TEXT_CHILD_TYPE_STATUS_TAG = "status-tag"
const PARSED_TEXT_CHILD_TYPE_LINK = "link"

const PARSED_TEXT_OUTGOING_STATUS_SENDING*   = "sending"
const PARSED_TEXT_OUTGOING_STATUS_SENT*      = "sent"
const PARSED_TEXT_OUTGOING_STATUS_DELIVERED* = "delivered"
const PARSED_TEXT_OUTGOING_STATUS_EXPIRED* = "expired"
const PARSED_TEXT_OUTGOING_STATUS_FAILED_RESENDING* = "failedResending"

# How status-go lists a mention of everyone ("@0x00001") in `mentions`
const EVERYONE_MENTION* = "0x00001"

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
  # The text as parsed by status-go: an array of markdown blocks, kept as JSON and only
  # walked for the plain text (see plainText)
  parsedText*: JsonNode
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
  # The mentions status-go found in the parsed text: public keys without the "@", and
  # EVERYONE_MENTION for a mention of everyone. Text in a quote, bold or code is not
  # searched for mentions.
  mentions*: seq[string]
  replied*: bool
  paymentRequests*: seq[PaymentRequest]

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

  var mentionsArr: JsonNode
  if jsonObj.getProp("mentions", mentionsArr) and mentionsArr.kind == JArray:
    for mention in mentionsArr:
      result.mentions.add(mention.getStr)

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
  if jsonObj.getProp("parsedText", parsedTextArr) and parsedTextArr.kind == JArray:
    result.parsedText = parsedTextArr

  var transactionParametersObj: JsonNode
  if(jsonObj.getProp("commandParameters", transactionParametersObj)):
    result.transactionParameters = toTransactionParameters(transactionParametersObj)

proc isPersonalMention*(self: MessageDto, publicKey: string): bool =
  return publicKey in self.mentions

proc isGlobalMention*(self: MessageDto): bool =
  return EVERYONE_MENTION in self.mentions

# The text a sticker, or an image without text, reads as in a one-line summary of it
const IMAGE_PLACEHOLDER_TEXT* = "🖼️"

# The markdown text of the message, which the client parses and renders. Bridged and
# imported Discord messages keep theirs in the bridge/Discord payload.
proc unparsedText*(self: MessageDto): string =
  if self.contentType == ContentType.BridgeMessage:
    return self.bridgeMessage.content
  if self.contentType == ContentType.DiscordMessage and self.text == "":
    return self.discordMessage.content
  return self.text

# The markdown text a chat shows for its last message: the message's text, or
# IMAGE_PLACEHOLDER_TEXT for a sticker or an image without text
proc lastMessageUnparsedText*(self: MessageDto): string =
  if self.contentType == ContentType.Sticker or
      (self.contentType == ContentType.Image and self.text == ""):
    return IMAGE_PLACEHOLDER_TEXT
  return self.unparsedText

# The plain text of status-go's parsed text: formatting dropped, one line per block, links
# shown as their destination and a mention as "@" and the name `mentionName` gives its
# literal (a public key, or EVERYONE_MENTION). Mentions in quotes keep their raw key, since
# status-go gives a quote as its literal text only.
proc plainText*(parsedText: JsonNode, mentionName: proc(mention: string): string): string =
  var lines: seq[string]
  for blockNode in parsedText.getElems:
    if blockNode{"type"}.getStr != PARSED_TEXT_TYPE_PARAGRAPH:
      # blockquote and codeblock: their text is the literal
      lines.add(blockNode{"literal"}.getStr.strip(leading = false))
      continue

    var line = ""
    for child in blockNode{"children"}.getElems:
      let literal = child{"literal"}.getStr
      case child{"type"}.getStr
        of PARSED_TEXT_CHILD_TYPE_MENTION:
          line.add("@" & mentionName(literal))
        of PARSED_TEXT_CHILD_TYPE_STATUS_TAG:
          line.add("#" & literal)
        of PARSED_TEXT_CHILD_TYPE_LINK:
          line.add(child{"destination"}.getStr)
        else:
          # text, code, emph, strong, strong-emph and del
          line.add(literal)
    lines.add(line)

  return lines.join("\n").strip()
