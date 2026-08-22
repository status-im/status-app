## Unit tests for the wire shapes of the windowed message-fetch API: the two
## window RPCs take a single JSON object where the rest of `wakuext` takes
## positional args, and every rank/count field carries a `-1` sentinel that must
## never be read as a position or as an empty chat.

import std/[json, os, strutils, tables]
import unittest

import app_service/service/message/message_window

suite "request params":
  test "the window calls take one object, not positional args":
    let params = aroundMessageParams("chat-1", "0xabc", 40)
    require(params.kind == JArray)
    require(params.len == 1)
    check(params[0].kind == JObject)
    check(params[0]["chatId"].getStr == "chat-1")
    check(params[0]["messageId"].getStr == "0xabc")
    check(params[0]["limit"].getInt == 40)

    let rankParams = atRankParams("chat-1", 1200, 40)
    require(rankParams.kind == JArray)
    require(rankParams.len == 1)
    check(rankParams[0]["chatId"].getStr == "chat-1")
    check(rankParams[0]["rank"].getInt == 1200)
    check(rankParams[0]["limit"].getInt == 40)

  test "the count call keeps the positional string param":
    let params = messagesCountParams("chat-1")
    require(params.kind == JArray)
    require(params.len == 1)
    check(params[0].kind == JString)
    check(params[0].getStr == "chat-1")

  test "limits are clamped into the range status-go validates":
    check(clampWindowLimit(0) == 1)
    check(clampWindowLimit(-5) == 1)
    check(clampWindowLimit(40) == 40)
    check(clampWindowLimit(MAX_MESSAGES_WINDOW_LIMIT) == MAX_MESSAGES_WINDOW_LIMIT)
    check(clampWindowLimit(MAX_MESSAGES_WINDOW_LIMIT + 1) == MAX_MESSAGES_WINDOW_LIMIT)
    check(atRankParams("chat-1", 0, 5000)[0]["limit"].getInt == MAX_MESSAGES_WINDOW_LIMIT)

  test "a negative rank never reaches the wire":
    check(atRankParams("chat-1", -3, 40)[0]["rank"].getInt == 0)

suite "rank and index conversion":
  test "rank 0 is the oldest row, which is the last model index":
    check(rankToIndex(10, 0) == 9)
    check(rankToIndex(10, 9) == 0)
    check(rankToIndex(1, 0) == 0)

  test "conversion round-trips":
    for index in 0 ..< 10:
      check(rankToIndex(10, indexToRank(10, index)) == index)

  test "the not-applicable sentinel never becomes a position":
    check(rankToIndex(10, RANK_NOT_APPLICABLE) == -1)
    check(rankToIndex(0, 0) == -1)
    check(rankToIndex(10, 10) == -1)
    check(indexToRank(10, -1) == RANK_NOT_APPLICABLE)
    check(indexToRank(0, 0) == RANK_NOT_APPLICABLE)

suite "worker-side response assembly":
  let rpcResult = %*{
    "messages": [{"id": "0xc"}, {"id": "0xb"}, {"id": "0xa"}],
    "reactions": [{"id": "r1", "messageId": "0xb"}],
    "cursor": "next-page",
    "totalCount": 1240,
    "firstRank": 1239,
    "anchorRank": 1150,
  }

  test "the enriched fields survive the hand-over to the GUI thread":
    let response = buildWindowResponse("chat-1", rpcResult)
    check(response["chatId"].getStr == "chat-1")
    check(response["messages"].len == 3)
    check(response["messagesCursor"].getStr == "next-page")
    check(response["totalCount"].getInt == 1240)
    check(response["firstRank"].getInt == 1239)
    check(response["anchorRank"].getInt == 1150)
    check(response["reactions"].len == 1)

  test "a response without the enriched fields reports the sentinels":
    let plain = %*{"messages": [], "cursor": ""}
    let response = buildWindowResponse("chat-1", plain)
    check(response["totalCount"].getInt == COUNT_UNKNOWN)
    check(response["firstRank"].getInt == RANK_NOT_APPLICABLE)
    check(response["anchorRank"].getInt == RANK_NOT_APPLICABLE)
    check(response["messages"].kind == JArray)
    check(response["reactions"].kind == JArray)

  test "a page past the end of the chat keeps its count and drops its rank":
    let pastEnd = %*{"messages": [], "cursor": "", "totalCount": 1240, "firstRank": -1, "anchorRank": -1}
    let response = buildWindowResponse("chat-1", pastEnd)
    check(response["totalCount"].getInt == 1240)
    check(response["firstRank"].getInt == RANK_NOT_APPLICABLE)

suite "page reactions":
  # status-go embeds the page's reactions in the page response, so the whole
  # page costs one call. The array is flat and unordered: a reaction names its
  # message through `messageId`, never through its position in the array.
  let pageWithReactions = %*{
    "messages": [{"id": "0xc"}, {"id": "0xb"}, {"id": "0xa"}],
    "reactions": [
      {"id": "r-a1", "messageId": "0xa", "emojiId": 1},
      {"id": "r-c1", "messageId": "0xc", "emojiId": 2},
      {"id": "r-c2", "messageId": "0xc", "emojiId": 3},
    ],
    "cursor": "",
    "totalCount": 1240,
    "firstRank": 1239,
    "anchorRank": -1,
  }

  proc byMessageId(reactions: JsonNode): Table[string, seq[string]] =
    result = initTable[string, seq[string]]()
    for reaction in reactions.getElems():
      result.mgetOrPut(reaction["messageId"].getStr, @[]).add(reaction["id"].getStr)

  test "the page's own reactions are what the payload carries":
    let payload = buildWindowPayload("chat-1", pageWithReactions)
    check(payload.reactions.kind == JArray)
    check(payload.reactions.len == 3)
    check(payload.reactions == pageWithReactions["reactions"])

  test "reactions group by messageId, several on one row and none on another":
    let grouped = byMessageId(buildWindowPayload("chat-1", pageWithReactions).reactions)
    check(grouped.len == 2)
    check(grouped["0xc"] == @["r-c1", "r-c2"])
    check(grouped["0xa"] == @["r-a1"])
    check(not grouped.hasKey("0xb"))

  test "a reaction belongs to the message it names, not to the row it lines up with":
    # The fixture is deliberately misaligned: pairing reactions[i] with
    # messages[i] would hand 0xc's reactions to 0xa. If a future edit makes the
    # two arrays line up, this check fails and the misalignment must be restored.
    let messages = pageWithReactions["messages"]
    let reactions = pageWithReactions["reactions"]
    require(reactions.len <= messages.len)
    check(reactions[0]["messageId"].getStr != messages[0]["id"].getStr)

    let grouped = byMessageId(buildWindowPayload("chat-1", pageWithReactions).reactions)
    check(not grouped.hasKey("0xb"))
    for i in 0 ..< reactions.len:
      let named = reactions[i]["messageId"].getStr
      check(reactions[i]["id"].getStr in grouped[named])

  test "no reactions on the page is an empty array, never nil":
    let empty = buildWindowPayload("chat-1", %*{"messages": [{"id": "0xa"}], "reactions": []})
    check(empty.reactions.kind == JArray)
    check(empty.reactions.len == 0)

  test "a response without the field, or with a null one, reads as no reactions":
    # A page from a status-go that predates the embedded field must read as
    # "nobody reacted", not as a nil array the GUI slot would trip over.
    for rpcResult in [%*{"messages": []}, %*{"messages": [], "reactions": newJNull()}]:
      let payload = buildWindowPayload("chat-1", rpcResult)
      check(payload.reactions.kind == JArray)
      check(payload.reactions.len == 0)
    check(pageReactions(newJArray()).kind == JArray)
    check(pageReactions(newJArray()).len == 0)

suite "the page path never fetches reactions per message":
  # A source-text guard, not a behavioural one: the worker tasks call the RPC
  # transport, which cannot be linked here. It fails if the per-message loop
  # that made a 40-row page cost 40 sequential calls comes back.
  let asyncTasks = readFile(currentSourcePath.parentDir.parentDir.parentDir /
    "src/app_service/service/message/async_tasks.nim")

  proc sliceBetween(text, first, last: string): string =
    let start = text.find(first)
    let stop = text.find(last, start + 1)
    require(start >= 0)
    require(stop > start)
    text[start ..< stop]

  test "the three page tasks issue no reaction call of their own":
    let pagePath = sliceBetween(asyncTasks,
      "proc asyncFetchChatMessagesTask", "proc asyncFetchChatMessagesCountTask")
    check("asyncFetchChatMessagesAroundMessageTask" in pagePath)
    check("asyncFetchChatMessagesAtRankTask" in pagePath)
    check(not pagePath.contains("fetchReactions"))

  test "the single-message and pinned-message paths keep their own fetch":
    # Reacting to a message refreshes just that message, and pinned messages are
    # not a page; neither is served by the embedded array.
    check(asyncTasks.contains("fetchReactionsForMessageWithId"))

suite "GUI-side response parsing":
  test "a full page parses into meta":
    let meta = parseMessagePageMeta(%*{
      "chatId": "chat-1",
      "messagesCursor": "next-page",
      "totalCount": 1240,
      "firstRank": 1239,
      "anchorRank": 1150,
    })
    check(meta.error == "")
    check(meta.chatId == "chat-1")
    check(meta.cursor == "next-page")
    check(meta.totalCount == 1240)
    check(meta.firstRank == 1239)
    check(meta.anchorRank == 1150)

  test "an errored response keeps its chat id and carries no numbers":
    let meta = parseMessagePageMeta(%*{
      "chatId": "chat-1",
      "error": "record not found",
      "totalCount": 1240,
    })
    check(meta.error == "record not found")
    check(meta.chatId == "chat-1")
    check(meta.totalCount == COUNT_UNKNOWN)
    check(meta.firstRank == RANK_NOT_APPLICABLE)
    check(meta.anchorRank == RANK_NOT_APPLICABLE)

  test "a non-object response is an error, not an empty page":
    let meta = parseMessagePageMeta(%*[1, 2, 3])
    check(meta.error.len > 0)
    check(meta.totalCount == COUNT_UNKNOWN)

  test "a missing rank is not rank 0":
    let meta = parseMessagePageMeta(%*{"chatId": "chat-1", "messagesCursor": ""})
    check(meta.firstRank == RANK_NOT_APPLICABLE)
    check(meta.anchorRank == RANK_NOT_APPLICABLE)
    check(meta.totalCount == COUNT_UNKNOWN)

  test "a chat with no messages reports count 0 and no rank":
    let meta = parseMessagePageMeta(%*{"chatId": "chat-1", "totalCount": 0, "firstRank": -1})
    check(meta.totalCount == 0)
    check(meta.firstRank == RANK_NOT_APPLICABLE)

  test "the oldest rank of a page":
    var meta = initMessagePageMeta("chat-1")
    meta.firstRank = 1239
    check(meta.lastRank(40) == 1200)
    check(meta.lastRank(0) == RANK_NOT_APPLICABLE)
    meta.firstRank = RANK_NOT_APPLICABLE
    check(meta.lastRank(40) == RANK_NOT_APPLICABLE)

  test "a short page around an anchor near the oldest end stops at rank 0":
    # around-message is not backfilled, so an anchor near an end returns fewer
    # rows than the limit
    var meta = initMessagePageMeta("chat-1")
    meta.firstRank = 5
    check(meta.lastRank(20) == 0)

suite "chat message counts":
  test "one entry per affected chat, indexed by chat id":
    let counts = toChatMessageCounts(%*[
      {"chatId": "chat-b", "totalCount": 7},
      {"chatId": "chat-a", "totalCount": 1240},
    ])
    check(counts.len == 2)
    check(counts["chat-a"] == 1240)
    check(counts["chat-b"] == 7)

  test "a cleared chat reports zero, not absence":
    let counts = toChatMessageCounts(%*[{"chatId": "chat-a", "totalCount": 0}])
    check(counts.len == 1)
    check(counts["chat-a"] == 0)

  test "malformed entries are dropped rather than defaulted":
    let counts = toChatMessageCounts(%*[
      {"chatId": "", "totalCount": 5},
      {"chatId": "chat-a"},
      {"totalCount": 5},
      "not-an-object",
      {"chatId": "chat-b", "totalCount": 3},
    ])
    check(counts.len == 1)
    check(counts["chat-b"] == 3)

  test "an absent or non-array field is no counts at all":
    check(toChatMessageCounts(nil).len == 0)
    check(toChatMessageCounts(newJNull()).len == 0)
    check(toChatMessageCounts(%*{"chatId": "chat-a"}).len == 0)
