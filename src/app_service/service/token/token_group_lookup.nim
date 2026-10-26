## Bounded cache of on-demand token-group lookups.
##
## Replaces the index of the whole token catalogue by group key: a group that is
## not among the tokens of interest is fetched from the backend once, and the
## result (an empty one included) is kept until the token lists refresh. The
## cache holds at most `capacity` groups, evicting the oldest.

import tables, deques, sequtils

import items/token

type
  GroupTokensFetchResult* = object
    ok*: bool  ## false on a backend error: the result is not cached
    tokens*: seq[TokenItem]

  GroupTokensFetch* = proc(groupKey: string): GroupTokensFetchResult {.closure.}

  GroupTokensCache* = object
    capacity: int
    tokensByGroupKey: Table[string, seq[TokenItem]]
    insertionOrder: Deque[string]

proc initGroupTokensCache*(capacity = 256): GroupTokensCache =
  GroupTokensCache(capacity: capacity)

proc len*(cache: GroupTokensCache): int =
  cache.tokensByGroupKey.len

proc clear*(cache: var GroupTokensCache) =
  cache.tokensByGroupKey.clear()
  cache.insertionOrder.clear()

proc lookup*(cache: var GroupTokensCache, groupKey: string, fetch: GroupTokensFetch): seq[TokenItem] =
  cache.tokensByGroupKey.withValue(groupKey, tokens):
    return tokens[]
  let fetched = fetch(groupKey)
  if not fetched.ok:
    return @[]
  result = fetched.tokens.filterIt(it.groupKey == groupKey)
  if cache.tokensByGroupKey.len >= cache.capacity:
    cache.tokensByGroupKey.del(cache.insertionOrder.popFirst())
  cache.tokensByGroupKey[groupKey] = result
  cache.insertionOrder.addLast(groupKey)
