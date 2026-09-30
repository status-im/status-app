## Unit tests for the pure on-demand price request tracker.
## The periodic refresh prices only the tokens of interest; a catalog token the
## swap modal settles on is asked for through this tracker. It must ask once per
## burst, skip what is already priced or in flight, back off what the provider
## returned unpriced, and hand the periodic refresh the keys to keep fresh.
## No Qt/backend.

import unittest, sequtils, sets, tables

import app_service/service/token/token_price_requests

proc priced(pairs: varargs[(string, float64)]): Table[string, float64] =
  for (k, v) in pairs:
    result[k] = v

suite "on-demand price requests — what gets asked for":
  test "a key without a price is asked for once per burst":
    var r = initOnDemandPriceRequests()
    check r.request(["4663-0x1inch"], priced(), now = 100) == true  # newly pending -> schedule
    check r.request(["4663-0x1inch"], priced(), now = 100) == false # already pending -> no second schedule
    check r.takeBatch() == @["4663-0x1inch"]
    check not r.hasPending()

  test "keys already priced are not asked for":
    var r = initOnDemandPriceRequests()
    check r.request(["1-0xeth"], priced(("1-0xeth", 2680.0)), now = 100) == false
    check not r.hasPending()

  test "a price of zero in the cache still counts as unpriced":
    var r = initOnDemandPriceRequests()
    check r.request(["1-0xsnt"], priced(("1-0xsnt", 0.0)), now = 100) == true

  test "empty keys are ignored":
    var r = initOnDemandPriceRequests()
    check r.request([""], priced(), now = 100) == false

  test "a group's keys are batched, priced ones left out":
    var r = initOnDemandPriceRequests()
    check r.request(["1-0x1inch", "4663-0x1inch", "10-0x1inch"], priced(("1-0x1inch", 0.3)), now = 100)
    check r.takeBatch().toHashSet == ["4663-0x1inch", "10-0x1inch"].toHashSet

suite "on-demand price requests — in flight and backoff":
  test "a key in flight is not asked for again until its batch completes":
    var r = initOnDemandPriceRequests()
    discard r.request(["4663-0x1inch"], priced(), now = 100)
    let batch = r.takeBatch()
    check r.request(["4663-0x1inch"], priced(), now = 100) == false
    r.completeBatch(batch, pricedKeys = ["4663-0x1inch"].toHashSet, now = 101)
    # priced now, so the cache lookup is what keeps it from being re-asked
    check r.request(["4663-0x1inch"], priced(("4663-0x1inch", 0.3)), now = 102) == false

  test "a key the provider returned unpriced is backed off, then asked again":
    var r = initOnDemandPriceRequests()
    discard r.request(["10-0xdust"], priced(), now = 100)
    r.completeBatch(r.takeBatch(), pricedKeys = initHashSet[string](), now = 100)
    check r.request(["10-0xdust"], priced(), now = 100 + UNPRICED_RETRY_AFTER_SECONDS - 1) == false
    check r.request(["10-0xdust"], priced(), now = 100 + UNPRICED_RETRY_AFTER_SECONDS) == true

  test "a priced answer clears an earlier backoff":
    var r = initOnDemandPriceRequests()
    discard r.request(["10-0xlate"], priced(), now = 100)
    r.completeBatch(r.takeBatch(), pricedKeys = initHashSet[string](), now = 100)
    # the periodic refresh re-fetches remembered keys and this time it is priced
    r.completeBatch(["10-0xlate"], pricedKeys = ["10-0xlate"].toHashSet, now = 200)
    # the cache would now hold it; with the cache reset (currency change) it is asked for at once
    check r.request(["10-0xlate"], priced(), now = 201) == true

  test "releasing a batch (answer dropped) neither prices nor backs off its keys":
    var r = initOnDemandPriceRequests()
    discard r.request(["4663-0x1inch"], priced(), now = 100)
    r.releaseBatch(r.takeBatch())
    check r.request(["4663-0x1inch"], priced(), now = 100) == true

  test "draining in flight releases keys of a batch that could not be decoded":
    var r = initOnDemandPriceRequests()
    discard r.request(["4663-0x1inch"], priced(), now = 100)
    discard r.takeBatch()
    r.drainInFlight()
    check r.request(["4663-0x1inch"], priced(), now = 100) == true

suite "on-demand price requests — keeping them fresh":
  test "keys asked for on demand are remembered for the periodic refresh":
    var r = initOnDemandPriceRequests()
    discard r.request(["4663-0x1inch"], priced(), now = 100)
    check r.rememberedKeys().len == 0 # only once handed to a batch
    discard r.takeBatch()
    check r.rememberedKeys() == @["4663-0x1inch"]

  test "the remembered keys are bounded, oldest forgotten first":
    var r = initOnDemandPriceRequests()
    for i in 0 ..< REMEMBERED_KEYS_LIMIT + 5:
      discard r.request(["1-0x" & $i], priced(), now = 100)
      discard r.takeBatch()
    let kept = r.rememberedKeys()
    check kept.len == REMEMBERED_KEYS_LIMIT
    check kept[0] == "1-0x5"
    check kept[^1] == "1-0x" & $(REMEMBERED_KEYS_LIMIT + 4)

  test "a cache reset keeps the remembered keys but drops pending, in flight and backoff":
    var r = initOnDemandPriceRequests()
    discard r.request(["10-0xdust"], priced(), now = 100)
    r.completeBatch(r.takeBatch(), pricedKeys = initHashSet[string](), now = 100) # backed off
    discard r.request(["4663-0x1inch"], priced(), now = 100)
    discard r.takeBatch() # in flight
    discard r.request(["1-0xpending"], priced(), now = 100)
    r.resetForRefetch()
    check not r.hasPending()
    check r.rememberedKeys().toHashSet == ["10-0xdust", "4663-0x1inch"].toHashSet
    check r.request(["10-0xdust", "4663-0x1inch"], priced(), now = 100) == true
    check r.takeBatch().toHashSet == ["10-0xdust", "4663-0x1inch"].toHashSet
