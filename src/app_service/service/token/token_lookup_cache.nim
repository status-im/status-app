## Pure helpers for the wallet token-service lookup cache.
##
## A by-key token lookup that finds nothing must cache that negative result;
## otherwise every repeat lookup of a missing key re-fires a blocking GUI-thread
## RPC. These helpers make negative results first-class and keep the refresh-apply
## path swap-not-clear, so they can be unit-tested without the backend or a live
## Service.

import tables, sets

import items/token

type TokenLookupOutcome* {.pure.} = enum
  Hit          ## token is cached -> return it, no RPC
  KnownMissing ## backend already reported "not found" -> return nil, no RPC
  NeedsFetch   ## nothing known about the key -> a backend fetch is required

proc classifyTokenLookup*(
    tokensByKey: Table[string, TokenItem],
    knownMissingKeys: HashSet[string],
    key: string): TokenLookupOutcome =
  ## Decide what a by-key lookup should do. A key that resolved to "not found"
  ## on a previous lookup is remembered in `knownMissingKeys`, so it never costs
  ## another RPC until the caches are refreshed.
  if tokensByKey.hasKey(key):
    return TokenLookupOutcome.Hit
  if key in knownMissingKeys:
    return TokenLookupOutcome.KnownMissing
  return TokenLookupOutcome.NeedsFetch

proc shouldReplaceTokensCache*(newTokenCount: int, priorCacheCount: int): bool =
  ## Swap-not-clear guard for applying a token refresh. Replace the cache only
  ## when the refresh actually carries data, or when the cache is empty anyway
  ## (first fill). An empty/failed refresh with an existing cache is ignored so
  ## the previous state is preserved rather than wiped.
  newTokenCount > 0 or priorCacheCount == 0

proc buildTokensByKey*(tokens: seq[TokenItem]): Table[string, TokenItem] =
  ## Build the replacement by-key lookup table aside so the caller can swap it in
  ## atomically. Never clear-then-fill the live table: that would expose a window
  ## where every lookup misses.
  var byKey = initTable[string, TokenItem](tokens.len)
  for token in tokens:
    byKey[token.key] = token
  return byKey
