## Pure bookkeeping for on-demand token prices.
##
## The periodic price refresh covers only the tokens of interest (tokens some
## account holds, their cross-chain siblings, the mandatory tokens), so a catalog
## token picked in the swap modal has no price until somebody asks for it. This
## tracks what to ask for: a request dedups against keys already priced, pending
## or in flight, keys the provider returned unpriced are backed off so they are
## not asked again on every selection change, and every key asked for on demand
## is remembered so the periodic refresh keeps it fresh. No scheduling, threads
## or IO here, so it can be unit-tested without a Service or backend.

import sequtils, sets, tables

const
  ## a key the provider returned unpriced is not asked for again sooner
  UNPRICED_RETRY_AFTER_SECONDS* = 10 * 60
  ## bound on the on-demand keys the periodic refresh keeps fresh; past it the
  ## oldest are forgotten (a fresh selection asks for them again)
  REMEMBERED_KEYS_LIMIT* = 200

type OnDemandPriceRequests* = object
  pending: HashSet[string]            ## keys awaiting the next batch
  inFlight: HashSet[string]           ## keys handed to a batch already running
  remembered: seq[string]             ## on-demand keys, oldest first
  rememberedSet: HashSet[string]
  unpricedUntil: Table[string, int64] ## key -> unix time after which it may be asked for again

proc initOnDemandPriceRequests*(): OnDemandPriceRequests =
  OnDemandPriceRequests(
    pending: initHashSet[string](),
    inFlight: initHashSet[string](),
    rememberedSet: initHashSet[string](),
    unpricedUntil: initTable[string, int64]())

proc hasPrice(prices: Table[string, float64], key: string): bool =
  prices.getOrDefault(key, 0.0) > 0.0

proc request*(self: var OnDemandPriceRequests, keys: openArray[string], prices: Table[string, float64], now: int64): bool =
  ## Record the keys worth asking for. Returns true only when at least one key
  ## is newly pending; the caller uses that to schedule (debounce) a batch once
  ## per burst. Keys already priced, pending, in flight or backed off are skipped.
  for key in keys:
    if key.len == 0 or prices.hasPrice(key):
      continue
    if key in self.pending or key in self.inFlight:
      continue
    if self.unpricedUntil.getOrDefault(key, 0'i64) > now:
      continue
    self.pending.incl(key)
    result = true

proc hasPending*(self: OnDemandPriceRequests): bool =
  self.pending.len > 0

proc remember(self: var OnDemandPriceRequests, key: string) =
  if key in self.rememberedSet:
    return
  self.remembered.add(key)
  self.rememberedSet.incl(key)
  while self.remembered.len > REMEMBERED_KEYS_LIMIT:
    self.rememberedSet.excl(self.remembered[0])
    self.remembered.delete(0)

proc takeBatch*(self: var OnDemandPriceRequests): seq[string] =
  result = toSeq(self.pending)
  for key in result:
    self.inFlight.incl(key)
    self.remember(key)
  self.pending.clear()

proc completeBatch*(self: var OnDemandPriceRequests, requestedKeys: openArray[string],
    pricedKeys: HashSet[string], now: int64) =
  for key in requestedKeys:
    self.inFlight.excl(key)
    if key in pricedKeys:
      self.unpricedUntil.del(key)
    else:
      self.unpricedUntil[key] = now + UNPRICED_RETRY_AFTER_SECONDS

proc releaseBatch*(self: var OnDemandPriceRequests, requestedKeys: openArray[string]) =
  for key in requestedKeys:
    self.inFlight.excl(key)

proc drainInFlight*(self: var OnDemandPriceRequests) =
  self.inFlight.clear()

proc rememberedKeys*(self: OnDemandPriceRequests): seq[string] =
  self.remembered

proc resetForRefetch*(self: var OnDemandPriceRequests) =
  self.pending.clear()
  self.inFlight.clear()
  self.unpricedUntil.clear()
