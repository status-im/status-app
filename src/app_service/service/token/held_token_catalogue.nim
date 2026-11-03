## The token service's catalogue copies as held resources: the token lists, all
## token groups of the active networks, and the token groups of each chain. Each
## is fetched for its first holder and dropped after the idle release, or at once
## on background. Every load and drop is reported, so no model keeps reading a
## dropped copy, and so is every change of whether a copy is loading.

import std/tables

import app/core/held_resource
import items/token_list, items/token_group

export held_resource

type
  TokenCatalogueKind* = enum
    tckTokenLists
    tckAllTokenGroups
    tckChainTokenGroups

  MakeHeldResource* = proc(name: string, onLoad: proc(generation: int), onDrop: proc()): HeldResource
  MakeHeldResources*[K] = proc(name: string, onLoad: proc(key: K, generation: int),
    onDrop: proc(key: K)): HeldResources[K]

  # At most one fetch runs per copy: a load started meanwhile fetches once it
  # is done, and only the latest load's result is applied.
  LoadTask = object
    # the load whose result is awaited, 0 for none
    awaited: int
    # the load whose fetch runs, 0 for none
    running: int

  LoadOutcome = enum
    loStale
    loRefetch
    loCurrent

  HeldSeq*[T] = ref object
    resource: HeldResource
    data: seq[T]
    task: LoadTask
    fetch: proc(generation: int)
    changed: proc(dropped: bool)
    loadingChanged: proc()

  HeldSeqs*[K, T] = ref object
    resources: HeldResources[K]
    data: Table[K, seq[T]]
    tasks: Table[K, LoadTask]
    empty: seq[T]
    fetch: proc(key: K, generation: int)
    changed: proc(key: K, dropped: bool)
    loadingChanged: proc(key: K)

  TokenCatalogueFetches* = object
    tokenLists*: proc(generation: int)
    allTokenGroups*: proc(generation: int)
    chainTokenGroups*: proc(chainId: int, generation: int)

  HeldTokenCatalogue* = ref object
    tokenLists*: HeldSeq[TokenListItem]
    allTokenGroups*: HeldSeq[TokenGroupItem]
    chainTokenGroups*: HeldSeqs[int, TokenGroupItem]

proc start(task: var LoadTask, generation: int): bool =
  ## Whether the fetch for `generation` starts now.
  task.awaited = generation
  if task.running != 0:
    return false
  task.running = generation
  true

proc settle(task: var LoadTask, generation: int): LoadOutcome =
  ## On loRefetch the fetch for `task.running` is to start.
  if generation == 0 or generation != task.running:
    return loStale
  task.running = 0
  if generation == task.awaited:
    task.awaited = 0
    return loCurrent
  if task.awaited == 0:
    return loStale
  task.running = task.awaited
  loRefetch

proc idle(task: LoadTask): bool =
  task.awaited == 0 and task.running == 0

proc newHeldSeq[T](name: string, make: MakeHeldResource, fetch: proc(generation: int),
    changed: proc(dropped: bool), loadingChanged: proc()): HeldSeq[T] =
  let held = HeldSeq[T](fetch: fetch, changed: changed, loadingChanged: loadingChanged)
  held.resource = make(name,
    onLoad = proc(generation: int) =
      let wasLoading = held.task.awaited != 0
      if held.task.start(generation):
        held.fetch(generation)
      if not wasLoading:
        held.loadingChanged(),
    onDrop = proc() =
      let wasLoading = held.task.awaited != 0
      held.task.awaited = 0
      held.data = @[]
      held.changed(dropped = true)
      if wasLoading:
        held.loadingChanged(),
  )
  held

proc acquire*[T](self: HeldSeq[T]) = self.resource.acquire()
proc release*[T](self: HeldSeq[T]) = self.resource.release()
proc invalidate*[T](self: HeldSeq[T]) = self.resource.invalidate()

proc items*[T](self: HeldSeq[T]): var seq[T] =
  self.data

proc isLoading*[T](self: HeldSeq[T]): bool =
  self.task.awaited != 0

proc complete*[T](self: HeldSeq[T], generation: int, ok: bool, items: sink seq[T]) =
  case self.task.settle(generation)
  of loStale:
    return
  of loRefetch:
    self.fetch(self.task.running)
    return
  of loCurrent:
    discard
  if ok:
    self.data = items
    self.resource.onLoadSucceeded(generation)
    self.changed(dropped = false)
  else:
    self.resource.onLoadFailed(generation)
    # a drop has reported already
    if self.resource.isActive or self.resource.holderCount > 0:
      self.changed(dropped = false)
  self.loadingChanged()

proc newHeldSeqs[K, T](name: string, make: MakeHeldResources[K], fetch: proc(key: K, generation: int),
    changed: proc(key: K, dropped: bool), loadingChanged: proc(key: K)): HeldSeqs[K, T] =
  let held = HeldSeqs[K, T](fetch: fetch, changed: changed, loadingChanged: loadingChanged)
  held.resources = make(name,
    onLoad = proc(key: K, generation: int) =
      let wasLoading = held.tasks.getOrDefault(key).awaited != 0
      if held.tasks.mgetOrPut(key, LoadTask()).start(generation):
        held.fetch(key, generation)
      if not wasLoading:
        held.loadingChanged(key),
    onDrop = proc(key: K) =
      let wasLoading = held.tasks.getOrDefault(key).awaited != 0
      held.tasks.withValue(key, task):
        task.awaited = 0
        if task[].idle:
          held.tasks.del(key)
      held.data.del(key)
      held.changed(key, dropped = true)
      if wasLoading:
        held.loadingChanged(key),
  )
  held

proc acquire*[K, T](self: HeldSeqs[K, T], key: K) = self.resources.acquire(key)
proc release*[K, T](self: HeldSeqs[K, T], key: K) = self.resources.release(key)
proc invalidateAll*[K, T](self: HeldSeqs[K, T]) = self.resources.invalidateAll()

proc isActive*[K, T](self: HeldSeqs[K, T], key: K): bool =
  ## From the first holder until the drop.
  self.resources.isActive(key)

proc items*[K, T](self: HeldSeqs[K, T], key: K): var seq[T] =
  ## Empty for a key that is not loaded.
  self.data.withValue(key, value):
    return value[]
  self.empty.setLen(0)
  self.empty

proc isLoading*[K, T](self: HeldSeqs[K, T], key: K): bool =
  self.tasks.getOrDefault(key).awaited != 0

proc complete*[K, T](self: HeldSeqs[K, T], key: K, generation: int, ok: bool, items: sink seq[T]) =
  var outcome = loStale
  var next = 0
  self.tasks.withValue(key, task):
    outcome = task[].settle(generation)
    next = task.running
    if task[].idle:
      self.tasks.del(key)
  case outcome
  of loStale:
    return
  of loRefetch:
    self.fetch(key, next)
    return
  of loCurrent:
    discard
  if ok:
    self.data[key] = items
    self.resources.onLoadSucceeded(key, generation)
    self.changed(key, dropped = false)
  else:
    self.resources.onLoadFailed(key, generation)
    if self.resources.isActive(key) or self.resources.holderCount(key) > 0:
      self.changed(key, dropped = false)
  self.loadingChanged(key)

proc newHeldTokenCatalogue*(makeResource: MakeHeldResource, makeKeyedResources: MakeHeldResources[int],
    fetches: TokenCatalogueFetches, changed: proc(kind: TokenCatalogueKind, chainId: int, dropped: bool),
    loadingChanged: proc(kind: TokenCatalogueKind, chainId: int)): HeldTokenCatalogue =
  HeldTokenCatalogue(
    tokenLists: newHeldSeq[TokenListItem]("token lists", makeResource, fetches.tokenLists,
      proc(dropped: bool) = changed(tckTokenLists, 0, dropped), proc() = loadingChanged(tckTokenLists, 0)),
    allTokenGroups: newHeldSeq[TokenGroupItem]("all token groups", makeResource, fetches.allTokenGroups,
      proc(dropped: bool) = changed(tckAllTokenGroups, 0, dropped), proc() = loadingChanged(tckAllTokenGroups, 0)),
    chainTokenGroups: newHeldSeqs[int, TokenGroupItem]("chain token groups", makeKeyedResources,
      fetches.chainTokenGroups, proc(chainId: int, dropped: bool) = changed(tckChainTokenGroups, chainId, dropped),
      proc(chainId: int) = loadingChanged(tckChainTokenGroups, chainId)),
  )

proc onTokenListsUpdated*(self: HeldTokenCatalogue) =
  self.tokenLists.invalidate()
  self.allTokenGroups.invalidate()
  self.chainTokenGroups.invalidateAll()

proc onNetworkModeUpdated*(self: HeldTokenCatalogue) =
  self.allTokenGroups.invalidate()
  self.chainTokenGroups.invalidateAll()

proc onActiveNetworksUpdated*(self: HeldTokenCatalogue) =
  self.allTokenGroups.invalidate()

proc onBackgrounded*(self: HeldTokenCatalogue) =
  self.tokenLists.resource.onBackgrounded()
  self.allTokenGroups.resource.onBackgrounded()
  self.chainTokenGroups.resources.onBackgrounded()

proc onForegrounded*(self: HeldTokenCatalogue) =
  self.tokenLists.resource.onForegrounded()
  self.allTokenGroups.resource.onForegrounded()
  self.chainTokenGroups.resources.onForegrounded()

proc dispose*(self: HeldTokenCatalogue) =
  self.tokenLists.resource.dispose()
  self.allTokenGroups.resource.dispose()
  self.chainTokenGroups.resources.dispose()
