## Unit tests for the wire shapes of the windowed message-fetch API: the two
## window RPCs take a single JSON object where the rest of `wakuext` takes
## positional args, and every rank/count field carries a `-1` sentinel that must
## never be read as a position or as an empty chat.

import std/[json, tables]
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
    "cursor": "next-page",
    "totalCount": 1240,
    "firstRank": 1239,
    "anchorRank": 1150,
  }

  test "the enriched fields survive the hand-over to the GUI thread":
    let response = buildWindowResponse("chat-1", rpcResult, %*[{"id": "r1"}])
    check(response["chatId"].getStr == "chat-1")
    check(response["messages"].len == 3)
    check(response["messagesCursor"].getStr == "next-page")
    check(response["totalCount"].getInt == 1240)
    check(response["firstRank"].getInt == 1239)
    check(response["anchorRank"].getInt == 1150)
    check(response["reactions"].len == 1)

  test "a response without the enriched fields reports the sentinels":
    let plain = %*{"messages": [], "cursor": ""}
    let response = buildWindowResponse("chat-1", plain, nil)
    check(response["totalCount"].getInt == COUNT_UNKNOWN)
    check(response["firstRank"].getInt == RANK_NOT_APPLICABLE)
    check(response["anchorRank"].getInt == RANK_NOT_APPLICABLE)
    check(response["messages"].kind == JArray)
    check(response["reactions"].kind == JArray)

  test "a page past the end of the chat keeps its count and drops its rank":
    let pastEnd = %*{"messages": [], "cursor": "", "totalCount": 1240, "firstRank": -1, "anchorRank": -1}
    let response = buildWindowResponse("chat-1", pastEnd, nil)
    check(response["totalCount"].getInt == 1240)
    check(response["firstRank"].getInt == RANK_NOT_APPLICABLE)

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
