import unittest, json, strutils

import app_service/common/types
import app_service/service/message/dto/message

const myKey = "0x04" & repeat("a", 128)
const otherKey = "0x04" & repeat("b", 128)

# A message as status-go sends it: the parsed text, and the mentions it found in it,
# without the "@"
proc messageWithMentions(mentions: seq[string]): MessageDto =
  var children = %*[{"literal": "hi"}]
  for mention in mentions:
    children.add(%*{"type": "mention", "literal": mention})
  return toMessageDto(%*{
    "id": "0x1",
    "text": "hi @" & mentions.join(" @"),
    "parsedText": [{"type": "paragraph", "children": children}],
    "mentions": mentions,
  })

suite "message mentions":

  test "mentions are read from the status-go message":
    check(messageWithMentions(@[myKey, EVERYONE_MENTION]).mentions == @[myKey, EVERYONE_MENTION])
    check(toMessageDto(%*{"id": "0x1", "text": "hi"}).mentions.len == 0)

  test "a mention of the user is a personal mention":
    let message = messageWithMentions(@[otherKey, myKey])
    check(message.isPersonalMention(myKey))
    check(not message.isGlobalMention())

  test "a mention of somebody else is no mention of the user":
    check(not messageWithMentions(@[otherKey]).isPersonalMention(myKey))

  test "a mention of everyone is a global mention":
    let message = messageWithMentions(@[EVERYONE_MENTION])
    check(message.isGlobalMention())
    check(not message.isPersonalMention(myKey))

suite "message plain text":

  # The names of the mentioned users, as the message service resolves them
  proc mentionName(mention: string): string =
    if mention == EVERYONE_MENTION: "everyone"
    elif mention == myKey: "Me"
    else: "Somebody"

  # parsedText as status-go's markdown parser produces it for the message
  proc plainTextOf(parsedText: string): string =
    let message = toMessageDto(%*{"id": "0x1", "parsedText": parseJson(parsedText)})
    return plainText(message.parsedText, mentionName)

  test "formatting is dropped, mentions get names and links their destination":
    # hi **bold** *it* ***both*** ~~del~~ `code` @<myKey> @0x00001 #general https://status.app
    check(plainTextOf("""[{"type":"paragraph","children":[{"literal":"hi "},
      {"type":"strong","literal":"bold"},{"literal":" "},{"type":"emph","literal":"it"},{"literal":" "},
      {"type":"strong-emph","literal":"both"},{"literal":" "},{"type":"del","literal":"del"},{"literal":" "},
      {"type":"code","literal":"code"},{"literal":" "},{"type":"mention","literal":"""" & myKey & """"},
      {"literal":" "},{"type":"mention","literal":"0x00001"},{"literal":" "},
      {"type":"status-tag","literal":"general"},{"literal":" "},
      {"type":"link","children":[{"literal":"https://status.app"}],"literal":"","title":"",
       "destination":"https://status.app"}]}]""") ==
      "hi bold it both del code @Me @everyone #general https://status.app")

  test "line breaks and paragraphs become lines":
    check(plainTextOf("""[{"type":"paragraph","children":[{"literal":"line1\nline2"}]}]""") ==
      "line1\nline2")
    check(plainTextOf("""[{"type":"paragraph","children":[{"literal":"para one"}]},
      {"type":"paragraph","children":[{"literal":"para two"}]}]""") == "para one\npara two")

  test "quotes and code blocks keep their text":
    # status-go gives a quote as its literal only, so a mention in it stays a raw key
    check(plainTextOf("""[{"type":"blockquote","children":null,"literal":"quote @0x04b\nmore"}]""") ==
      "quote @0x04b\nmore")
    check(plainTextOf("""[{"type":"paragraph","children":[{"literal":"text"}]},
      {"type":"codeblock","literal":"code\n  indented\n"},
      {"type":"paragraph","children":[{"literal":"after"}]}]""") == "text\ncode\n  indented\nafter")

  test "markup characters stay as they are":
    check(plainTextOf("""[{"type":"paragraph","children":[{"literal":"<b>html</b> & stuff <3"}]}]""") ==
      "<b>html</b> & stuff <3")

  test "a message without parsed text has no plain text":
    check(plainText(toMessageDto(%*{"id": "0x1"}).parsedText, mentionName) == "")

suite "message unparsed text":

  proc messageOf(contentType: ContentType, fields: JsonNode = newJObject()): MessageDto =
    var json = %*{"id": "0x1", "contentType": contentType.int}
    for key, value in fields:
      json[key] = value
    return toMessageDto(json)

  test "a message's text is its markdown":
    check(messageOf(ContentType.Message, %*{"text": "**hi** @0x04b"}).unparsedText == "**hi** @0x04b")

  test "bridged and Discord messages take their text from the payload":
    check(messageOf(ContentType.BridgeMessage,
      %*{"text": "ignored", "bridgeMessage": {"content": "from the bridge"}}).unparsedText == "from the bridge")
    check(messageOf(ContentType.DiscordMessage,
      %*{"discordMessage": {"content": "from Discord"}}).unparsedText == "from Discord")
    check(messageOf(ContentType.DiscordMessage,
      %*{"text": "own text", "discordMessage": {"content": "from Discord"}}).unparsedText == "own text")

  test "a chat's last message shows stickers and images without text as a placeholder":
    check(messageOf(ContentType.Sticker).lastMessageUnparsedText == IMAGE_PLACEHOLDER_TEXT)
    check(messageOf(ContentType.Image).lastMessageUnparsedText == IMAGE_PLACEHOLDER_TEXT)
    check(messageOf(ContentType.Image, %*{"text": "*look*"}).lastMessageUnparsedText == "*look*")
    check(messageOf(ContentType.BridgeMessage,
      %*{"bridgeMessage": {"content": "bridged"}}).lastMessageUnparsedText == "bridged")
    check(MessageDto().lastMessageUnparsedText == "")
