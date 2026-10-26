## Bounded cache of on-demand token-group lookups: empty results are cached too,
## failed fetches are not; at most `capacity` groups, the oldest evicted first.

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
