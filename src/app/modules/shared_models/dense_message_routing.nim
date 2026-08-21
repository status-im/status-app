## Where a message-service response or signal lands in the dense model.
##
## Deliberately generic over the model and the item type rather than typed
## against `DenseModel`: the model shell needs nimqml, which cannot be linked in
## a host unit test, while every rule here is exactly the kind that breaks
## silently — a `-1` that becomes rank 0, an empty page applied as if it were a
## real one, a backfilled message appended as if it were live, a signal for a
## different chat applied to this one. Instantiated against `DenseModel`/`Item`
## in production and against a recording stub in the tests, so both run the same
## code.

{.used.}

import app_service/service/message/message_window

export message_window

const NO_CLOCK* = int64.low
  ## "the model knows of no message yet" — distinct from clock 0.

# --------------------------------------------------------- application rules

proc applyMessagePage*[M, I](model: M, items: seq[I], firstRank: int,
    totalCount = COUNT_UNKNOWN) =
  ## A fetched page. `items` is newest-first and `items[i]` has rank
  ## `firstRank - i`, so a page without a rank cannot be placed at all — an
  ## empty page reports `firstRank: -1` and would otherwise be written over the
  ## oldest end of the chat. Its count is still news and is applied.
  if items.len == 0 or firstRank == RANK_NOT_APPLICABLE:
    model.setTotalCount(totalCount)
    return
  model.applyPage(items, firstRank, totalCount)

proc isLiveMessage*[I](item: I, newestClock: int64): bool =
  ## A message at or past the newest clock the model knows lands at the newest
  ## end; anything older arrived out of band (mailserver backfill) and has to be
  ## located by cursor instead.
  newestClock == NO_CLOCK or item.clock >= newestClock

proc applyIncomingMessages*[M, I](model: M, items: seq[I], newestClock: int64,
    totalCount = COUNT_UNKNOWN) =
  ## The `messages.new` batch: live messages and mailserver backfill arrive
  ## through the same signal, so they are split before they reach the model.
  ## The count, when the batch carried one, describes the state after all of
  ## them and is applied once at the end.
  var live: seq[I] = @[]
  for item in items:
    if item.isLiveMessage(newestClock):
      live.add(item)
    else:
      model.addBackfilledMessage(item, COUNT_UNKNOWN)
  if live.len > 0:
    model.addLiveMessages(live, COUNT_UNKNOWN)
  model.setTotalCount(totalCount)

proc applyMessageRemoval*[M](model: M, messageId: string, clock: int64,
    totalCount = COUNT_UNKNOWN) =
  ## The count that travels with a batch is the count after the *whole* batch,
  ## so removals are applied without it and the count arrives on its own signal;
  ## applying it per removal would shrink the model once per message plus once
  ## for the batch.
  if messageId.len == 0:
    return
  model.messageDeleted(messageId, clock, totalCount)

proc applyChatMessageCount*[M](model: M, totalCount: int) =
  if totalCount == COUNT_UNKNOWN:
    return
  model.setTotalCount(totalCount)

proc applyChatReset*[M](model: M, totalCount: int) =
  ## Chat switch. An unknown count means an empty model until the count arrives.
  model.resetToChat(max(0, totalCount))

# ---------------------------------------------------------------- the router

type
  DenseChatRouter*[M] = ref object
    ## One per chat view. Every message signal is broadcast to all chats, so
    ## the chatId check is the first thing each entry point does.
    chatId*: string
    model*: M

proc newDenseChatRouter*[M](chatId: string, model: M): DenseChatRouter[M] =
  DenseChatRouter[M](chatId: chatId, model: model)

proc handles*[M](self: DenseChatRouter[M], chatId: string): bool =
  self.chatId.len > 0 and self.chatId == chatId

proc onChatReset*[M](self: DenseChatRouter[M], totalCount: int) =
  self.model.applyChatReset(totalCount)

proc onMessagePageLoaded*[M, I](self: DenseChatRouter[M], chatId: string,
    items: seq[I], firstRank: int, totalCount = COUNT_UNKNOWN) =
  if not self.handles(chatId):
    return
  self.model.applyMessagePage(items, firstRank, totalCount)

proc onIncomingMessages*[M, I](self: DenseChatRouter[M], chatId: string,
    items: seq[I], totalCount = COUNT_UNKNOWN) =
  if not self.handles(chatId):
    return
  self.model.applyIncomingMessages(items, self.model.newestLoadedClock, totalCount)

proc onMessageRemoved*[M](self: DenseChatRouter[M], chatId, messageId: string, clock: int64) =
  if not self.handles(chatId):
    return
  self.model.applyMessageRemoval(messageId, clock)

proc onChatMessageCount*[M](self: DenseChatRouter[M], chatId: string, totalCount: int) =
  if not self.handles(chatId):
    return
  self.model.applyChatMessageCount(totalCount)

proc anchorIndex*[M](self: DenseChatRouter[M], anchorRank: int): int =
  ## Rank -> model index at the boundary; `-1` in stays `-1` out.
  rankToIndex(self.model.totalCount, anchorRank)
