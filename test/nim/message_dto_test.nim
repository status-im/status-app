import unittest, json, strutils

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
