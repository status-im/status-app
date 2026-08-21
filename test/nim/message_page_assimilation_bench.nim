## Phase-1 measurement for issue 0017 — where the cost of assimilating a
## message page actually falls.
##
## Splits the current `loadMoreMessages` completion into its three stages and
## times each one against a synthetic-but-realistic community-channel page:
##
##   worker  : `Json.encode(responseJson)`   (qt.nim `finish` serializes here)
##   GUI slot: `response.parseJson`          (whole page re-parsed)
##   GUI slot: `toMessageDto` / `toReactionDto` per row
##   GUI slot: `createMessageItemFromDtos` per row (item construction)
##
## Run (see the issue's Results section for the seaqt link recipe — the DTOs are
## Qt-linked, so this needs the seaqt paths plus libstatus/libqrcodegen).

import json, times, strformat, strutils, sequtils

import json_serialization
from eth/common/eth_types_json_serialization import writeValue, readValue

import app_service/service/contacts/dto/contact_details
import app_service/service/message/dto/message
import app_service/service/message/dto/reaction
import app_service/service/message/message_window
import app/modules/shared_models/message_model
import app/modules/shared_models/message_item

const Sizes = [20, 30, 40, 100, 250, 500]
const Reps = 25

proc pubkey(i: int): string =
  "0x04" & align($i, 126, '0')

proc syntheticMessage(i: int, chatId: string): JsonNode =
  ## A community-channel row: a paragraph of parsed text with a mention and a
  ## link child, occasional link preview, occasional reply quote.
  let sender = pubkey(i mod 40)
  let body = "Message " & $i & ": " &
    "the quick brown fox jumps over the lazy dog and keeps going for a while " &
    "so the row has a realistic amount of text to render and wrap. "

  var children = newJArray()
  children.add(%*{"type": "text", "literal": body})
  if i mod 3 == 0:
    children.add(%*{"type": "mention", "literal": pubkey((i + 7) mod 40)})
  if i mod 5 == 0:
    children.add(%*{"type": "link", "literal": "https://status.im/post/" & $i,
                    "destination": "https://status.im/post/" & $i})

  result = %*{
    "id": "0x" & align($i, 64, 'a'),
    "chatId": chatId,
    "localChatId": chatId,
    "communityId": "0x03communityaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "from": sender,
    "alias": "Brave Silly Otter",
    "seen": true,
    "outgoingStatus": "",
    "rtl": false,
    "lineCount": 2,
    "text": body,
    "clock": 1700000000000 + i,
    "timestamp": 1700000000 + i,
    "contentType": 1,
    "messageType": 1,
    "replace": "",
    "responseTo": (if i mod 9 == 0: "0x" & align($(i - 1), 64, 'a') else: ""),
    "ensName": "",
    "image": "",
    "albumId": "",
    "albumImagesCount": 0,
    "editedAt": 0,
    "deleted": false,
    "deletedBy": "",
    "deletedForMe": false,
    "mentioned": i mod 3 == 0,
    "replied": false,
    "links": (if i mod 5 == 0: %[%("https://status.im/post/" & $i)] else: newJArray()),
    "parsedText": %[%*{"type": "paragraph", "children": children}],
  }

  if i mod 9 == 0:
    result["quotedMessage"] = %*{
      "from": pubkey((i + 3) mod 40),
      "text": "an earlier message being quoted here",
      "contentType": 1,
      "parsedText": %[%*{"type": "paragraph",
                         "children": %[%*{"type": "text", "literal": "an earlier message being quoted here"}]}],
    }

  if i mod 11 == 0:
    result["linkPreviews"] = %[%*{
      "url": "https://status.im/post/" & $i,
      "type": 1,
      "hostname": "status.im",
      "title": "A linked article with a reasonably long title " & $i,
      "description": "And a description that runs on for a sentence or two, the way " &
        "an OpenGraph description usually does.",
      "thumbnail": %*{"width": 1200, "height": 630, "url": ""},
    }]

proc syntheticReaction(messageId: string, i, k: int): JsonNode =
  %*{
    "id": "0xr" & align($(i * 4 + k), 62, '0'),
    "clock": 1700000000000 + i,
    "chatId": "chat",
    "localChatId": "chat",
    "from": pubkey((i + k) mod 40),
    "messageId": messageId,
    "emojiId": 1 + k,
    "retracted": false,
  }

proc syntheticPage(count: int): JsonNode =
  let chatId = "0x03communityaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa0x1234"
  var messages = newJArray()
  var reactions = newJArray()
  for i in 0 ..< count:
    let msg = syntheticMessage(i, chatId)
    messages.add(msg)
    # roughly a fifth of the rows carry one or two reactions
    if i mod 5 == 0:
      reactions.add(syntheticReaction(msg["id"].getStr, i, 0))
    if i mod 13 == 0:
      reactions.add(syntheticReaction(msg["id"].getStr, i, 1))

  buildWindowResponse(chatId, %*{
    "messages": messages,
    "cursor": "cursor-" & $count,
    "totalCount": 12000,
    "firstRank": 8000,
    "anchorRank": -1,
  }, reactions)

template timeIt(body: untyped): float =
  ## Best-of-`Reps` wall milliseconds — the floor, so a stray GC or scheduler
  ## hiccup cannot flatter the "before" number.
  var best = high(float)
  for _ in 0 ..< Reps:
    let t0 = cpuTime()
    body
    let dt = (cpuTime() - t0) * 1000.0
    if dt < best: best = dt
  best

proc decodeMessages(responseObj: JsonNode): seq[MessageDto] =
  map(responseObj["messages"].getElems(), proc(x: JsonNode): MessageDto = x.toMessageDto())

proc decodeReactions(responseObj: JsonNode): seq[ReactionDto] =
  map(responseObj["reactions"].getElems(), proc(x: JsonNode): ReactionDto = x.toReactionDto())

proc buildItems(messages: seq[MessageDto]): seq[Item] =
  ## The remainder that cannot leave the GUI thread: item construction reads the
  ## contacts service, the community's chat list and the user-profile singleton.
  ## Timed here with those lookups stubbed out, so it is a LOWER BOUND on the
  ## real GUI-thread item cost, never an over-estimate.
  let sender = ContactDetails()
  for m in messages:
    result.add(message_model.createMessageItemFromDtos(
      message = m,
      communityId = m.communityId,
      sender = sender,
      isCurrentUser = false,
      renderedMessageText = m.text,
      clearText = m.text,
    ))

when isMainModule:
  echo "issue 0017 — Phase 1: message-page assimilation cost split"
  echo ""
  echo "| rows | payload KB | worker encode ms | GUI parseJson ms | GUI DTO decode ms | GUI item build ms | GUI total ms |"
  echo "|---|---|---|---|---|---|---|"

  for size in Sizes:
    let page = syntheticPage(size)
    var encoded = ""
    let encodeMs = timeIt: encoded = Json.encode(page)
    let payloadKb = encoded.len.float / 1024.0

    var parsed: JsonNode
    let parseMs = timeIt: parsed = encoded.parseJson

    var msgs: seq[MessageDto]
    var rxns: seq[ReactionDto]
    let decodeMs = timeIt:
      msgs = decodeMessages(parsed)
      rxns = decodeReactions(parsed)

    var items: seq[Item]
    let itemMs = timeIt: items = buildItems(msgs)

    doAssert msgs.len == size
    doAssert items.len == size
    doAssert rxns.len > 0

    echo &"| {size} | {payloadKb:.1f} | {encodeMs:.2f} | {parseMs:.2f} | {decodeMs:.2f} | {itemMs:.2f} | {parseMs + decodeMs + itemMs:.2f} |"

  echo ""
  echo "GUI total = parseJson + DTO decode + item build (what the completion slot runs today)."
  echo "Movable off-thread = parseJson + DTO decode. Item build stays (GUI-owned services)."
