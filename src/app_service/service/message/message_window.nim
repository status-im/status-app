## Wire shapes for the windowed message-fetch API (status-go `wakuext_chatMessages*`).
##
## Pure Nim on purpose: this is the seam where a rank of `-1` must stay `-1` and
## where the two window calls take a single JSON *object* param instead of the
## positional args the rest of `wakuext` uses. Both are easy to get wrong and
## impossible to unit-test once nimqml or the RPC transport is in the picture,
## so the request builders and the response parsers live here and the backend
## wrappers, the worker tasks and the service handlers are thin over them.

{.used.}

import json, tables

const RANK_NOT_APPLICABLE* = -1
  ## status-go never hands out rank 0 to mean "no rank": an empty page, a
  ## non-chat-scoped page and an unanchored page all report -1.

const COUNT_UNKNOWN* = -1
  ## No count travelled with this response; the model must keep the one it has.

const MAX_MESSAGES_WINDOW_LIMIT* = 1000
  ## `MaxMessagesWindowLimit` in status-go; a larger limit fails validation.

type
  MessagePageMeta* = object
    ## The scalar half of the enriched `ApplicationMessagesResponse`. The
    ## message and reaction arrays stay as DTOs in the service — they drag in
    ## the whole contact/link-preview graph, and none of it is needed to decide
    ## where a page goes.
    ##
    ## The page itself is NEWEST-FIRST and contiguous by rank: `messages[i]` has
    ## rank `firstRank - i`.
    chatId*: string
    cursor*: string
    totalCount*: int
    firstRank*: int
    anchorRank*: int
    error*: string

proc initMessagePageMeta*(chatId = ""): MessagePageMeta =
  MessagePageMeta(
    chatId: chatId,
    totalCount: COUNT_UNKNOWN,
    firstRank: RANK_NOT_APPLICABLE,
    anchorRank: RANK_NOT_APPLICABLE,
  )

# ------------------------------------------------------------ rank <-> index

proc rankToIndex*(totalCount, rank: int): int =
  ## Ranks count from the oldest message, the model is newest-first. `-1` is not
  ## a position and never becomes one.
  if rank < 0 or totalCount <= 0 or rank >= totalCount:
    return -1
  totalCount - 1 - rank

proc indexToRank*(totalCount, index: int): int =
  if index < 0 or totalCount <= 0 or index >= totalCount:
    return RANK_NOT_APPLICABLE
  totalCount - 1 - index

# --------------------------------------------------------- request builders

proc clampWindowLimit*(limit: int): int =
  if limit < 1: 1
  elif limit > MAX_MESSAGES_WINDOW_LIMIT: MAX_MESSAGES_WINDOW_LIMIT
  else: limit

proc aroundMessageParams*(chatId, messageId: string, limit: int): JsonNode =
  ## `wakuext_chatMessagesAroundMessage` takes one object, not positional args.
  %*[{
    "chatId": chatId,
    "messageId": messageId,
    "limit": clampWindowLimit(limit),
  }]

proc atRankParams*(chatId: string, rank, limit: int): JsonNode =
  ## `wakuext_chatMessagesAtRank`; rank must be >= 0 to pass validation.
  %*[{
    "chatId": chatId,
    "rank": max(0, rank),
    "limit": clampWindowLimit(limit),
  }]

proc messagesCountParams*(chatId: string): JsonNode =
  %*[chatId]

# ---------------------------------------------------------------- responses

proc readRank(node: JsonNode, prop: string): int =
  ## A missing rank field is "not applicable", not rank 0 — the pre-enrichment
  ## backend and the enriched one must not be told apart by an off-by-one.
  if node.kind != JObject or not node.hasKey(prop) or node[prop].kind != JInt:
    return RANK_NOT_APPLICABLE
  let value = node[prop].getInt
  if value < 0: RANK_NOT_APPLICABLE else: value

proc readCount(node: JsonNode, prop: string): int =
  if node.kind != JObject or not node.hasKey(prop) or node[prop].kind != JInt:
    return COUNT_UNKNOWN
  let value = node[prop].getInt
  if value < 0: COUNT_UNKNOWN else: value

proc buildWindowResponse*(chatId: string, rpcResult: JsonNode, reactions: JsonNode): JsonNode =
  ## Worker-side: flattens an `ApplicationMessagesResponse` plus the reactions
  ## fetched alongside it into the JSON the task hands to the GUI thread. Runs
  ## off the GUI thread; the GUI side only re-reads these named fields.
  result = %*{
    "chatId": chatId,
    "messages": (if rpcResult.kind == JObject and rpcResult.hasKey("messages"): rpcResult["messages"] else: newJArray()),
    "messagesCursor": (if rpcResult.kind == JObject and rpcResult.hasKey("cursor"): rpcResult["cursor"] else: newJString("")),
    "totalCount": readCount(rpcResult, "totalCount"),
    "firstRank": readRank(rpcResult, "firstRank"),
    "anchorRank": readRank(rpcResult, "anchorRank"),
    "reactions": (if reactions.isNil: newJArray() else: reactions),
  }

proc parseMessagePageMeta*(responseObj: JsonNode): MessagePageMeta =
  ## GUI-side counterpart of `buildWindowResponse`, for everything but the
  ## message and reaction arrays.
  result = initMessagePageMeta()
  if responseObj.isNil or responseObj.kind != JObject:
    result.error = "message page response is not a json object"
    return

  if responseObj.hasKey("chatId") and responseObj["chatId"].kind == JString:
    result.chatId = responseObj["chatId"].getStr

  if responseObj.hasKey("error") and responseObj["error"].kind == JString and
      responseObj["error"].getStr.len > 0:
    result.error = responseObj["error"].getStr
    return

  if responseObj.hasKey("messagesCursor") and responseObj["messagesCursor"].kind == JString:
    result.cursor = responseObj["messagesCursor"].getStr

  result.totalCount = readCount(responseObj, "totalCount")
  result.firstRank = readRank(responseObj, "firstRank")
  result.anchorRank = readRank(responseObj, "anchorRank")

proc lastRank*(meta: MessagePageMeta, messageCount: int): int =
  ## Rank of the oldest row of the page, or -1 when the page carries no rank.
  if meta.firstRank == RANK_NOT_APPLICABLE or messageCount <= 0:
    return RANK_NOT_APPLICABLE
  max(0, meta.firstRank - messageCount + 1)

# ------------------------------------------------------- count-bearing signals

proc toChatMessageCounts*(node: JsonNode): Table[string, int] =
  ## `chatMessageCounts` on a `MessengerResponse`: one entry per chat whose
  ## stored-message count the batch moved. Array order is not stable, so it is
  ## indexed by chatId.
  result = initTable[string, int]()
  if node.isNil or node.kind != JArray:
    return
  for entry in node:
    if entry.kind != JObject:
      continue
    if not entry.hasKey("chatId") or entry["chatId"].kind != JString:
      continue
    let chatId = entry["chatId"].getStr
    if chatId.len == 0:
      continue
    let count = readCount(entry, "totalCount")
    if count == COUNT_UNKNOWN:
      continue
    result[chatId] = count
