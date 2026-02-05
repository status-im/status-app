import nimqml, std/json, sequtils, sugar, strutils
import stint, chronicles, tables

import app/modules/shared_models/collectibles_entry
import app/modules/shared_models/collectibles_model
import app/modules/shared_models/collectibles_utils
import events_handler

import app/core/eventemitter

import backend/collectibles as backend_collectibles
import app_service/service/network/service as network_service

const FETCH_BATCH_COUNT_DEFAULT = 50

type
  LoadType* {.pure.} = enum
    AutoLoadSingleUpdate, # load all items and update the model once with full list
    AutoLoadPaginated,    # load items in batches (keep loading until the end of the list) and update the model appending each batch.
    OnDemand              # load items in batches (on demand when loadMoreItems is called) and update the model appending each batch.

proc isAutoLoad(self: LoadType): bool =
  return self == LoadType.AutoLoadSingleUpdate or self == LoadType.AutoLoadPaginated

proc isPaginated(self: LoadType): bool =
  return self == LoadType.AutoLoadPaginated or self == LoadType.OnDemand

QtObject:
  type
    Controller* = ref object of QObject
      networkService: network_service.Service

      model: Model
      fetchFromStart: bool
      tempItems: seq[CollectiblesEntry]

      eventsHandler: EventsHandler

      addresses: seq[string]
      chainIds: seq[int]
      selectedAddress: string
      filter: backend_collectibles.CollectibleFilter

      ownershipStatus: Table[string, Table[int, OwnershipStatus]] # Table[address][chainID] -> OwnershipStatus

      requestId: int32
      loadType: LoadType

      dataType: backend_collectibles.CollectibleDataType
      fetchCriteria: backend_collectibles.FetchCriteria

  proc setup(self: Controller)
  proc delete*(self: Controller)
  proc setupEventHandlers(self: Controller)
  proc newController*(
    requestId: int32,
    networkService: network_service.Service,
    events: EventEmitter,
    loadType: LoadType,
    dataType: backend_collectibles.CollectibleDataType = backend_collectibles.CollectibleDataType.Header,
    fetchCriteria: backend_collectibles.FetchCriteria = backend_collectibles.FetchCriteria(
      fetchType: backend_collectibles.FetchType.NeverFetch,
    )): Controller =
    new(result, delete)

    result.requestId = requestId
    result.loadType = loadType
    result.dataType = dataType
    result.fetchCriteria = fetchCriteria

    result.networkService = networkService

    result.model = newModel()
    result.fetchFromStart = true
  
    result.eventsHandler = newEventsHandler(result.requestId, events)

    result.addresses = @[]
    result.chainIds = @[]
    result.filter = backend_collectibles.newCollectibleFilterAllEntries()

    result.setup()

    result.setupEventHandlers()

    signalConnect(result.model, "loadMoreItems()", result, "onModelLoadMoreItems()")

  proc getModel*(self: Controller): Model =
    return self.model

  proc getModelAsVariant*(self: Controller): QVariant {.slot.} =
    return newQVariant(self.model)

  QtProperty[QVariant] model:
    read = getModelAsVariant

  proc checkModelState(self: Controller) =
    var overallState = OwnershipStateIdle

    # If any address+chainID is error, then the whole model is error
    # Otherwise, if any address+chainID is updating, then the whole model is updating
    # Otherwise, the model is idle
    for address, statusPerChainID in self.ownershipStatus.pairs:
      if not self.addresses.contains(address) or (self.selectedAddress != "" and self.selectedAddress != address):
        continue
      for chainID, status in statusPerChainID:
        if not self.chainIds.contains(chainID):
          continue
        if status.state == OwnershipStateError:
          overallState = OwnershipStateError
          break
        elif status.state == OwnershipStateUpdating:
          overallState = OwnershipStateUpdating
          break

    case overallState:
      of OwnershipStateIdle, OwnershipStateDelayed:
        self.model.setIsUpdating(false)
        self.model.setIsError(false)
      of OwnershipStateUpdating:
        self.model.setIsUpdating(true)
        self.model.setIsError(false)
      of OwnershipStateError:
        self.model.setIsUpdating(false)
        self.model.setIsError(true)
      of OwnershipStateNotAvailable:
        self.model.setIsUpdating(false)
        self.model.setIsError(false)

  proc resetOwnershipStatus(self: Controller) =
    # Initialize state table
    self.ownershipStatus = initTable[string, Table[int, OwnershipStatus]]()
    for address in self.addresses:
      self.ownershipStatus[address] = initTable[int, OwnershipStatus]()
      for chainID in self.chainIds:
        self.ownershipStatus[address][chainID] = OwnershipStatus(
          state: OwnershipStateUpdating,
          timestamp: backend_collectibles.invalidTimestamp
        )
    self.model.setIsUpdating(true)

  proc setOwnershipStatus(self: Controller, statusPerAddressAndChainID: Table[string, Table[int, OwnershipStatus]]) =
    for address, statusPerChainID in statusPerAddressAndChainID.pairs:
      if not self.ownershipStatus.hasKey(address):
        continue
      for chainID, status in statusPerChainID:
        if not self.ownershipStatus[address].hasKey(chainID):
          continue
        self.ownershipStatus[address][chainID] = status

    self.checkModelState()

  proc setOwnershipState(self: Controller, address: string, chainID: int, state: OwnershipState) =
    if not self.ownershipStatus.hasKey(address) or not self.ownershipStatus[address].hasKey(chainID):
      return
    self.ownershipStatus[address][chainID].state = state

    self.checkModelState()

  proc loadMoreItems(self: Controller) =
    if self.model.getIsFetching():
      return

    self.model.setIsFetching(true)
    self.model.setIsError(false)

    var offset = 0
    if not self.fetchFromStart:
      if self.loadType.isPaginated():
        offset = self.model.getCount()
      else:
        offset = self.tempItems.len
    self.fetchFromStart = false
    try:
      let response = backend_collectibles.getOwnedCollectiblesAsync(self.requestId, self.chainIds, self.addresses, self.filter, offset, FETCH_BATCH_COUNT_DEFAULT, self.dataType, self.fetchCriteria)
      if response.error != nil:
        self.model.setIsFetching(false)
        self.model.setIsError(true)
        self.fetchFromStart = true
        error "error fetching collectibles entries: ", error = response.error
    except Exception as e:
      error "error fetching collectibles entries: ", error = e.msg
      self.model.setIsFetching(false)
      self.model.setIsError(true)
      self.fetchFromStart = true

  proc onModelLoadMoreItems(self: Controller) {.slot.} =
    if self.loadType.isAutoLoad():
      return
    self.loadMoreItems()

  proc getExtraData(self: Controller, chainID: int): ExtraData =
    let network = self.networkService.getNetworkByChainId(chainID)
    if not network.isNil:
      return getExtraData(network)

  proc setTempItems(self: Controller, newItems: seq[CollectiblesEntry], offset: int) =
    if offset == 0:
      self.tempItems = @[]
    elif offset != self.tempItems.len:
      error "invalid offset"
      return
    self.tempItems.add(newItems)

  proc processGetOwnedCollectiblesResponse(self: Controller, response: JsonNode) =
    try: 
      let res = fromJson(response, backend_collectibles.GetOwnedCollectiblesResponse)

      let isError = res.errorCode != backend_collectibles.ErrorCodeSuccess

      if isError:
        error "error fetching collectibles entries: ", code = res.errorCode
        self.model.setIsError(true)
        self.model.setIsFetching(false)
        return

      let items = res.collectibles.map(header => (block:
        let extradata = self.getExtraData(header.id.contractID.chainID)
        newCollectibleDetailsFullEntry(header, extradata)
      ))
      
      if self.loadType.isPaginated():
        self.model.setItems(items, res.offset, res.hasMore)
      else:
        self.setTempItems(items, res.offset)
        if not res.hasMore:
          self.model.updateItems(self.tempItems)
          self.tempItems = @[]

      self.model.setIsFetching(false)
      self.setOwnershipStatus(res.ownershipStatus)

      if self.loadType.isAutoLoad() and res.hasMore:
        self.loadMoreItems()
      
    except Exception as e:
      error "Error converting activity entries: ", error = e.msg

  proc updateTempItems(self: Controller, updates: seq[backend_collectibles.Collectible]) =
    for i in countdown(self.tempItems.high, 0):
      let entry = self.tempItems[i]
      for j in countdown(updates.high, 0):
        if entry.updateDataIfSameID(updates[j]):
          break

  proc processCollectiblesDataUpdate(self: Controller, jsonObj: JsonNode) =
      if jsonObj.kind != JArray:
        error "processCollectiblesDataUpdate expected an array"

      var collectibles: seq[backend_collectibles.Collectible]
      for jsonCollectible in jsonObj.getElems():
        let collectible = fromJson(jsonCollectible, backend_collectibles.Collectible)
        collectibles.add(collectible)
      self.model.updateItemsData(collectibles)
      if not self.loadType.isPaginated():
        self.updateTempItems(collectibles)

  proc resetModel(self: Controller) {.slot.} =
    self.tempItems = @[]
    self.model.setItems(@[], 0, true)
    self.fetchFromStart = true
    if self.loadType.isAutoLoad():
      self.loadMoreItems() 

  proc setupEventHandlers(self: Controller) =
    self.eventsHandler.onOwnedCollectiblesFilteringDone(proc (jsonObj: JsonNode) =
      self.processGetOwnedCollectiblesResponse(jsonObj)
    )

    self.eventsHandler.onCollectiblesDataUpdate(proc (jsonObj: JsonNode) =
      self.processCollectiblesDataUpdate(jsonObj)
    )

    self.eventsHandler.onCollectiblesOwnershipUpdateStarted(proc (address: string, chainID: int) =
      self.setOwnershipState(address, chainID, OwnershipStateUpdating)
    )

    self.eventsHandler.onCollectiblesOwnershipUpdatePartial(proc (address: string, chainID: int, changes: backend_collectibles.OwnershipUpdateMessage) =
      self.setOwnershipState(address, chainID, OwnershipStateUpdating)
      if changes.hasChanges():
        self.resetModel() 
    )

    self.eventsHandler.onCollectiblesOwnershipUpdateFinished(proc (address: string, chainID: int, changes: backend_collectibles.OwnershipUpdateMessage) =
      self.setOwnershipState(address, chainID, OwnershipStateIdle)
      if changes.hasChanges():
        self.resetModel()
    )

    self.eventsHandler.onCollectiblesOwnershipUpdateFinishedWithError(proc (address: string, chainID: int) =
      self.setOwnershipState(address, chainID, OwnershipStateError)
    )

  proc setSelectedAccount*(self: Controller, address: string) =
    self.selectedAddress = address
    self.checkModelState()

  proc setFilterAddressesAndChains*(self: Controller, addresses: seq[string], chainIds: seq[int]) = 
    if chainIds == self.chainIds and addresses == self.addresses:
      return

    self.chainIds = chainIds
    self.addresses = addresses

    self.resetOwnershipStatus()
  
    self.eventsHandler.updateSubscribedAddresses(self.addresses)
    self.eventsHandler.updateSubscribedChainIDs(self.chainIds)

    self.resetModel()
  
  proc setFilter*(self: Controller, filter: backend_collectibles.CollectibleFilter) =
    if filter == self.filter:
      return

    self.filter = filter

    self.resetModel()

  proc getItemForData*(self: Controller, tokenId: string, tokenAddress: string, chainId: int): CollectiblesEntry =
    let uid = self.model.getUidForData(tokenId, tokenAddress, chainId)
    return self.model.getItemById(uid)

  proc setup(self: Controller) =
    self.QObject.setup

  proc delete*(self: Controller) =
    self.QObject.delete

