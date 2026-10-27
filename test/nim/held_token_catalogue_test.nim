## The token service's catalogue copies (token lists, all token groups, groups
## per chain) as held resources. Fetches, timers and the clock are injected, so
## no Qt, threadpool or backend is needed.

import std/[unittest, sequtils]

import app/core/held_resource
import app_service/service/token/held_token_catalogue
import app_service/service/token/items/token_list
import app_service/service/token/items/token_group
import app_service/service/token/dto/token_list as token_list_dto

type
  FakeClock = ref object
    now: int64
    timers: seq[FakeTimer]

  FakeTimer = ref object
    due: int64 # -1 while stopped
    fire: proc()

proc newTimer(clock: FakeClock): FakeTimer =
  result = FakeTimer(due: -1)
  clock.timers.add(result)

proc held(clock: FakeClock, timer: FakeTimer): HeldResourceTimer =
  HeldResourceTimer(
    start: proc(ms: int) = timer.due = clock.now + ms,
    stop: proc() = timer.due = -1,
  )

proc advance(clock: FakeClock, ms: int) =
  let target = clock.now + ms
  while true:
    var next: FakeTimer
    for timer in clock.timers:
      if timer.due >= 0 and timer.due <= target and (next.isNil or timer.due < next.due):
        next = timer
    if next.isNil:
      break
    clock.now = next.due
    next.due = -1
    next.fire()
  clock.now = target

proc resourceMaker(clock: FakeClock): MakeHeldResource =
  return proc(name: string, onLoad: proc(generation: int), onDrop: proc()): HeldResource =
    let release = clock.newTimer()
    let retry = clock.newTimer()
    let resource = newHeldResource(clock.held(release), clock.held(retry), onLoad, onDrop)
    release.fire = proc() = resource.onReleaseTimeout()
    retry.fire = proc() = resource.onRetryTimeout()
    resource

proc keyedResourceMaker(clock: FakeClock): MakeHeldResources[int] =
  return proc(name: string, onLoad: proc(key: int, generation: int), onDrop: proc(key: int)): HeldResources[int] =
    let release = clock.newTimer()
    let retry = clock.newTimer()
    let resources = newHeldResources[int](clock.held(release), clock.held(retry),
      now = proc(): int64 = clock.now, onLoad = onLoad, onDrop = onDrop)
    release.fire = proc() = resources.onReleaseTimeout()
    retry.fire = proc() = resources.onRetryTimeout()
    resources

type
  Fetch = tuple[kind: TokenCatalogueKind, chainId: int, generation: int]
  Change = tuple[kind: TokenCatalogueKind, chainId: int]

  Harness = ref object
    clock: FakeClock
    fetches: seq[Fetch]
    changes: seq[Change]
    drops: seq[Change]
    loadingChanges: seq[Change]
    catalogue: HeldTokenCatalogue

proc newHarness(): Harness =
  let h = Harness(clock: FakeClock())
  h.catalogue = newHeldTokenCatalogue(
    h.clock.resourceMaker(),
    h.clock.keyedResourceMaker(),
    TokenCatalogueFetches(
      tokenLists: proc(generation: int) = h.fetches.add((tckTokenLists, 0, generation)),
      allTokenGroups: proc(generation: int) = h.fetches.add((tckAllTokenGroups, 0, generation)),
      chainTokenGroups: proc(chainId: int, generation: int) =
        h.fetches.add((tckChainTokenGroups, chainId, generation)),
    ),
    changed = proc(kind: TokenCatalogueKind, chainId: int, dropped: bool) =
      h.changes.add((kind, chainId))
      if dropped:
        h.drops.add((kind, chainId)),
    loadingChanged = proc(kind: TokenCatalogueKind, chainId: int) = h.loadingChanges.add((kind, chainId)),
  )
  h

proc fetchesOf(h: Harness, kind: TokenCatalogueKind, chainId = 0): seq[Fetch] =
  h.fetches.filterIt(it.kind == kind and it.chainId == chainId)

proc lastGeneration(h: Harness, kind: TokenCatalogueKind, chainId = 0): int =
  h.fetchesOf(kind, chainId)[^1].generation

proc completeLatest(h: Harness) =
  ## Completes the latest fetch of each kind and chain, as if every task ran.
  let fetches = h.fetches
  for fetch in fetches:
    if fetch.generation != h.lastGeneration(fetch.kind, fetch.chainId):
      continue
    case fetch.kind
    of tckTokenLists: h.catalogue.tokenLists.complete(fetch.generation, ok = true, @[])
    of tckAllTokenGroups: h.catalogue.allTokenGroups.complete(fetch.generation, ok = true, @[])
    of tckChainTokenGroups:
      h.catalogue.chainTokenGroups.complete(fetch.chainId, fetch.generation, ok = true, @[])

proc group(key: string): TokenGroupItem = TokenGroupItem(key: key)
proc list(id: string): TokenListItem = createTokenListItem(TokenListDto(id: id))
proc keys(groups: seq[TokenGroupItem]): seq[string] = groups.mapIt(it.key)

suite "held token catalogue":
  setup:
    let h = newHarness()
    let catalogue = h.catalogue

  teardown:
    catalogue.dispose()

  test "nothing is fetched until the first holder":
    check h.fetches.len == 0
    catalogue.tokenLists.acquire()
    catalogue.allTokenGroups.acquire()
    catalogue.chainTokenGroups.acquire(1)
    check h.fetches.mapIt(it.kind) == @[tckTokenLists, tckAllTokenGroups, tckChainTokenGroups]

  test "a second holder does not fetch again":
    catalogue.allTokenGroups.acquire()
    catalogue.allTokenGroups.acquire()
    check h.fetchesOf(tckAllTokenGroups).len == 1

  test "a completed load is readable and reported":
    catalogue.allTokenGroups.acquire()
    check catalogue.allTokenGroups.isLoading
    catalogue.allTokenGroups.complete(h.lastGeneration(tckAllTokenGroups), ok = true, @[group("a"), group("b")])
    check not catalogue.allTokenGroups.isLoading
    check catalogue.allTokenGroups.items.keys == @["a", "b"]
    check h.changes == @[(tckAllTokenGroups, 0)]

  test "the last holder going drops the data after the idle delay":
    catalogue.tokenLists.acquire()
    catalogue.tokenLists.complete(h.lastGeneration(tckTokenLists), ok = true, @[list("uniswap")])
    h.changes.setLen(0)
    catalogue.tokenLists.release()
    h.clock.advance(DefaultIdleReleaseMs - 1)
    check catalogue.tokenLists.items.len == 1
    check h.changes.len == 0
    h.clock.advance(1)
    check catalogue.tokenLists.items.len == 0
    check h.changes == @[(tckTokenLists, 0)]

  test "a holder back within the idle delay reuses the data":
    catalogue.tokenLists.acquire()
    catalogue.tokenLists.complete(h.lastGeneration(tckTokenLists), ok = true, @[list("uniswap")])
    catalogue.tokenLists.release()
    h.clock.advance(DefaultIdleReleaseMs div 2)
    catalogue.tokenLists.acquire()
    h.clock.advance(DefaultIdleReleaseMs)
    check h.fetchesOf(tckTokenLists).len == 1
    check catalogue.tokenLists.items.len == 1

  test "both sides of a same-chain swap share one entry and one fetch":
    catalogue.chainTokenGroups.acquire(10)
    catalogue.chainTokenGroups.acquire(10)
    check h.fetchesOf(tckChainTokenGroups, 10).len == 1
    catalogue.chainTokenGroups.complete(10, h.lastGeneration(tckChainTokenGroups, 10), ok = true, @[group("eth")])
    catalogue.chainTokenGroups.release(10)
    h.clock.advance(DefaultIdleReleaseMs)
    check catalogue.chainTokenGroups.items(10).keys == @["eth"]

  test "switching chain A to B and back within the idle delay does not refetch A":
    catalogue.chainTokenGroups.acquire(1)
    catalogue.chainTokenGroups.complete(1, h.lastGeneration(tckChainTokenGroups, 1), ok = true, @[group("eth")])
    catalogue.chainTokenGroups.release(1)
    catalogue.chainTokenGroups.acquire(10)
    h.clock.advance(DefaultIdleReleaseMs div 2)
    catalogue.chainTokenGroups.release(10)
    catalogue.chainTokenGroups.acquire(1)
    check h.fetchesOf(tckChainTokenGroups, 1).len == 1
    check catalogue.chainTokenGroups.items(1).keys == @["eth"]
    h.clock.advance(DefaultIdleReleaseMs)
    check catalogue.chainTokenGroups.items(1).keys == @["eth"]
    check (tckChainTokenGroups, 10) in h.changes

  test "an unknown chain reads as empty":
    check catalogue.chainTokenGroups.items(5).len == 0
    check not catalogue.chainTokenGroups.isLoading(5)

  test "a dropped chain entry reads as empty and is reported":
    catalogue.chainTokenGroups.acquire(1)
    catalogue.chainTokenGroups.complete(1, h.lastGeneration(tckChainTokenGroups, 1), ok = true, @[group("eth")])
    catalogue.chainTokenGroups.release(1)
    h.changes.setLen(0)
    h.clock.advance(DefaultIdleReleaseMs)
    check catalogue.chainTokenGroups.items(1).len == 0
    check h.changes == @[(tckChainTokenGroups, 1)]

  test "only a drop is reported as one":
    catalogue.chainTokenGroups.acquire(1)
    catalogue.allTokenGroups.acquire()
    catalogue.chainTokenGroups.complete(1, h.lastGeneration(tckChainTokenGroups, 1), ok = true, @[group("eth")])
    catalogue.allTokenGroups.complete(h.lastGeneration(tckAllTokenGroups), ok = true, @[group("eth")])
    check h.changes.len == 2
    check h.drops.len == 0
    catalogue.chainTokenGroups.release(1)
    catalogue.allTokenGroups.release()
    h.clock.advance(DefaultIdleReleaseMs)
    check h.drops == @[(tckAllTokenGroups, 0), (tckChainTokenGroups, 1)] or
      h.drops == @[(tckChainTokenGroups, 1), (tckAllTokenGroups, 0)]

  test "a chain entry is active from its first holder until its drop":
    check not catalogue.chainTokenGroups.isActive(1)
    catalogue.chainTokenGroups.acquire(1)
    check catalogue.chainTokenGroups.isActive(1)
    catalogue.chainTokenGroups.complete(1, h.lastGeneration(tckChainTokenGroups, 1), ok = true, @[group("eth")])
    catalogue.chainTokenGroups.release(1)
    check catalogue.chainTokenGroups.isActive(1)
    h.clock.advance(DefaultIdleReleaseMs)
    check not catalogue.chainTokenGroups.isActive(1)

  test "a superseded load's result is ignored":
    catalogue.allTokenGroups.acquire()
    let first = h.lastGeneration(tckAllTokenGroups)
    catalogue.allTokenGroups.complete(first, ok = true, @[group("a")])
    catalogue.onNetworkModeUpdated()
    let second = h.lastGeneration(tckAllTokenGroups)
    check second != first
    catalogue.allTokenGroups.complete(first, ok = true, @[group("stale")])
    check catalogue.allTokenGroups.items.keys == @["a"]
    check catalogue.allTokenGroups.isLoading
    catalogue.allTokenGroups.complete(second, ok = true, @[group("b")])
    check catalogue.allTokenGroups.items.keys == @["b"]

  test "a load still in flight when invalidated is not applied; the reload fetches after it":
    catalogue.allTokenGroups.acquire()
    let first = h.lastGeneration(tckAllTokenGroups)
    catalogue.onActiveNetworksUpdated()
    check h.fetchesOf(tckAllTokenGroups).len == 1
    h.changes.setLen(0)
    catalogue.allTokenGroups.complete(first, ok = true, @[group("old")])
    check catalogue.allTokenGroups.items.len == 0
    check catalogue.allTokenGroups.isLoading
    check h.changes.len == 0
    let second = h.lastGeneration(tckAllTokenGroups)
    check second != first
    catalogue.allTokenGroups.complete(second, ok = true, @[group("new")])
    check catalogue.allTokenGroups.items.keys == @["new"]

  test "a chain load still in flight when invalidated is not applied":
    catalogue.chainTokenGroups.acquire(1)
    let first = h.lastGeneration(tckChainTokenGroups, 1)
    catalogue.onNetworkModeUpdated()
    h.changes.setLen(0)
    catalogue.chainTokenGroups.complete(1, first, ok = true, @[group("old")])
    check catalogue.chainTokenGroups.items(1).len == 0
    check catalogue.chainTokenGroups.isLoading(1)
    check h.changes.len == 0
    let second = h.lastGeneration(tckChainTokenGroups, 1)
    check second != first
    catalogue.chainTokenGroups.complete(1, second, ok = true, @[group("new")])
    check catalogue.chainTokenGroups.items(1).keys == @["new"]

  test "a token lists load still in flight when invalidated is not applied":
    catalogue.tokenLists.acquire()
    let first = h.lastGeneration(tckTokenLists)
    catalogue.onTokenListsUpdated()
    catalogue.tokenLists.complete(first, ok = true, @[list("old")])
    check catalogue.tokenLists.items.len == 0
    let second = h.lastGeneration(tckTokenLists)
    check second != first
    catalogue.tokenLists.complete(second, ok = true, @[list("new")])
    check catalogue.tokenLists.items.mapIt(it.id) == @["new"]

  test "a result arriving after the drop is ignored":
    catalogue.chainTokenGroups.acquire(1)
    let generation = h.lastGeneration(tckChainTokenGroups, 1)
    catalogue.chainTokenGroups.release(1)
    catalogue.onBackgrounded()
    catalogue.chainTokenGroups.complete(1, generation, ok = true, @[group("eth")])
    check catalogue.chainTokenGroups.items(1).len == 0

  test "a failed load stops loading and retries while held":
    catalogue.allTokenGroups.acquire()
    catalogue.allTokenGroups.complete(h.lastGeneration(tckAllTokenGroups), ok = false, @[])
    check not catalogue.allTokenGroups.isLoading
    check (tckAllTokenGroups, 0) in h.changes
    h.clock.advance(LoadRetryDelaysMs[0])
    check h.fetchesOf(tckAllTokenGroups).len == 2

  test "invalidating held data reloads it in place":
    catalogue.allTokenGroups.acquire()
    catalogue.allTokenGroups.complete(h.lastGeneration(tckAllTokenGroups), ok = true, @[group("a")])
    catalogue.onActiveNetworksUpdated()
    check h.fetchesOf(tckAllTokenGroups).len == 2
    check catalogue.allTokenGroups.items.keys == @["a"]

  test "invalidating idle data drops it now":
    catalogue.allTokenGroups.acquire()
    catalogue.allTokenGroups.complete(h.lastGeneration(tckAllTokenGroups), ok = true, @[group("a")])
    catalogue.allTokenGroups.release()
    catalogue.onActiveNetworksUpdated()
    check h.fetchesOf(tckAllTokenGroups).len == 1
    check catalogue.allTokenGroups.items.len == 0

  test "token lists updated while nothing is held fetches nothing":
    catalogue.onTokenListsUpdated()
    check h.fetches.len == 0

  test "token lists updated reloads every held kind":
    catalogue.tokenLists.acquire()
    catalogue.allTokenGroups.acquire()
    catalogue.chainTokenGroups.acquire(1)
    catalogue.chainTokenGroups.acquire(10)
    h.completeLatest()
    h.fetches.setLen(0)
    catalogue.onTokenListsUpdated()
    check h.fetches.mapIt((it.kind, it.chainId)).len == 4
    check h.fetchesOf(tckTokenLists).len == 1
    check h.fetchesOf(tckChainTokenGroups, 10).len == 1

  test "a network mode change reloads token groups and chain groups, not token lists":
    catalogue.tokenLists.acquire()
    catalogue.allTokenGroups.acquire()
    catalogue.chainTokenGroups.acquire(1)
    h.completeLatest()
    h.fetches.setLen(0)
    catalogue.onNetworkModeUpdated()
    check h.fetches.mapIt(it.kind) == @[tckAllTokenGroups, tckChainTokenGroups]

  test "an active networks change reloads only all token groups":
    catalogue.allTokenGroups.acquire()
    catalogue.chainTokenGroups.acquire(1)
    h.completeLatest()
    h.fetches.setLen(0)
    catalogue.onActiveNetworksUpdated()
    check h.fetches.mapIt(it.kind) == @[tckAllTokenGroups]

  test "backgrounding drops everything; foregrounding reloads what is held":
    catalogue.tokenLists.acquire()
    catalogue.tokenLists.complete(h.lastGeneration(tckTokenLists), ok = true, @[list("uniswap")])
    catalogue.chainTokenGroups.acquire(1)
    catalogue.chainTokenGroups.complete(1, h.lastGeneration(tckChainTokenGroups, 1), ok = true, @[group("eth")])
    catalogue.chainTokenGroups.acquire(10)
    catalogue.chainTokenGroups.release(10)
    h.fetches.setLen(0)
    catalogue.onBackgrounded()
    check catalogue.tokenLists.items.len == 0
    check catalogue.chainTokenGroups.items(1).len == 0
    check (tckChainTokenGroups, 10) in h.changes
    catalogue.onForegrounded()
    check h.fetches.mapIt((it.kind, it.chainId)) == @[(tckTokenLists, 0), (tckChainTokenGroups, 1)]

  test "invalidations while a load is in flight start one fetch, after it, for the latest load":
    catalogue.allTokenGroups.acquire()
    let first = h.lastGeneration(tckAllTokenGroups)
    catalogue.onActiveNetworksUpdated()
    catalogue.onNetworkModeUpdated()
    check h.fetchesOf(tckAllTokenGroups).len == 1
    catalogue.allTokenGroups.complete(first, ok = true, @[group("old")])
    check h.fetchesOf(tckAllTokenGroups).len == 2
    check catalogue.allTokenGroups.items.len == 0
    catalogue.allTokenGroups.complete(h.lastGeneration(tckAllTokenGroups), ok = true, @[group("new")])
    check catalogue.allTokenGroups.items.keys == @["new"]
    check not catalogue.allTokenGroups.isLoading
    check h.fetchesOf(tckAllTokenGroups).len == 2

  test "a superseded load that fails still starts the awaited fetch":
    catalogue.tokenLists.acquire()
    let first = h.lastGeneration(tckTokenLists)
    catalogue.onTokenListsUpdated()
    catalogue.tokenLists.complete(first, ok = false, @[])
    check h.fetchesOf(tckTokenLists).len == 2
    check catalogue.tokenLists.isLoading
    catalogue.tokenLists.complete(h.lastGeneration(tckTokenLists), ok = true, @[list("new")])
    check catalogue.tokenLists.items.mapIt(it.id) == @["new"]
    h.clock.advance(LoadRetryDelaysMs[^1])
    check h.fetchesOf(tckTokenLists).len == 2

  test "each chain keeps its own fetch in flight":
    catalogue.chainTokenGroups.acquire(1)
    catalogue.chainTokenGroups.acquire(10)
    catalogue.onNetworkModeUpdated()
    catalogue.onTokenListsUpdated()
    check h.fetchesOf(tckChainTokenGroups, 1).len == 1
    check h.fetchesOf(tckChainTokenGroups, 10).len == 1
    catalogue.chainTokenGroups.complete(1, h.lastGeneration(tckChainTokenGroups, 1), ok = true, @[group("old")])
    check h.fetchesOf(tckChainTokenGroups, 1).len == 2
    check h.fetchesOf(tckChainTokenGroups, 10).len == 1
    catalogue.chainTokenGroups.complete(1, h.lastGeneration(tckChainTokenGroups, 1), ok = true, @[group("eth")])
    check catalogue.chainTokenGroups.items(1).keys == @["eth"]
    check catalogue.chainTokenGroups.isLoading(10)
    catalogue.chainTokenGroups.complete(10, h.lastGeneration(tckChainTokenGroups, 10), ok = true, @[group("op")])
    check h.fetchesOf(tckChainTokenGroups, 10).len == 2
    catalogue.chainTokenGroups.complete(10, h.lastGeneration(tckChainTokenGroups, 10), ok = true, @[group("op")])
    check catalogue.chainTokenGroups.items(10).keys == @["op"]
    check h.fetchesOf(tckChainTokenGroups, 1).len == 2

  test "a holder back while the dropped load is still in flight fetches after it":
    catalogue.chainTokenGroups.acquire(1)
    let first = h.lastGeneration(tckChainTokenGroups, 1)
    catalogue.chainTokenGroups.release(1)
    catalogue.onBackgrounded()
    catalogue.chainTokenGroups.acquire(1)
    check h.fetchesOf(tckChainTokenGroups, 1).len == 1
    check catalogue.chainTokenGroups.isLoading(1)
    catalogue.chainTokenGroups.complete(1, first, ok = true, @[group("old")])
    check catalogue.chainTokenGroups.items(1).len == 0
    check h.fetchesOf(tckChainTokenGroups, 1).len == 2
    catalogue.chainTokenGroups.complete(1, h.lastGeneration(tckChainTokenGroups, 1), ok = true, @[group("eth")])
    check catalogue.chainTokenGroups.items(1).keys == @["eth"]

  test "a load dropped while in flight fetches nothing more":
    catalogue.allTokenGroups.acquire()
    let first = h.lastGeneration(tckAllTokenGroups)
    catalogue.allTokenGroups.release()
    catalogue.onBackgrounded()
    catalogue.allTokenGroups.complete(first, ok = true, @[group("a")])
    check h.fetchesOf(tckAllTokenGroups).len == 1
    check catalogue.allTokenGroups.items.len == 0

  test "a load start and its finish are reported as loading changes":
    catalogue.allTokenGroups.acquire()
    check h.loadingChanges == @[(tckAllTokenGroups, 0)]
    catalogue.allTokenGroups.complete(h.lastGeneration(tckAllTokenGroups), ok = true, @[group("a")])
    check h.loadingChanges == @[(tckAllTokenGroups, 0), (tckAllTokenGroups, 0)]
    check not catalogue.allTokenGroups.isLoading

  test "a reload of held data is reported as loading":
    catalogue.tokenLists.acquire()
    catalogue.tokenLists.complete(h.lastGeneration(tckTokenLists), ok = true, @[list("uniswap")])
    h.loadingChanges.setLen(0)
    catalogue.onTokenListsUpdated()
    check catalogue.tokenLists.isLoading
    check h.loadingChanges == @[(tckTokenLists, 0)]

  test "a failed load and its retry are reported as loading changes":
    catalogue.chainTokenGroups.acquire(1)
    h.loadingChanges.setLen(0)
    catalogue.chainTokenGroups.complete(1, h.lastGeneration(tckChainTokenGroups, 1), ok = false, @[])
    check h.loadingChanges == @[(tckChainTokenGroups, 1)]
    check not catalogue.chainTokenGroups.isLoading(1)
    h.clock.advance(LoadRetryDelaysMs[0])
    check catalogue.chainTokenGroups.isLoading(1)
    check h.loadingChanges == @[(tckChainTokenGroups, 1), (tckChainTokenGroups, 1)]

  test "dropping a loading copy is reported as a loading change":
    catalogue.allTokenGroups.acquire()
    catalogue.allTokenGroups.release()
    h.loadingChanges.setLen(0)
    catalogue.onBackgrounded()
    check not catalogue.allTokenGroups.isLoading
    check h.loadingChanges == @[(tckAllTokenGroups, 0)]

  test "nothing happens after dispose":
    catalogue.allTokenGroups.acquire()
    catalogue.dispose()
    catalogue.allTokenGroups.release()
    catalogue.chainTokenGroups.acquire(1)
    h.clock.advance(DefaultIdleReleaseMs)
    check h.fetches.len == 1
