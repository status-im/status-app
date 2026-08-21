import nimqml, chronicles, std/json, sequtils, sugar, options, strutils
import tables, stint, sets

import model
import entry
import recipients_model
import collectibles_model
import collectibles_item
import events_handler
import status
import utils

import web3/conversions

import app/core/eventemitter
import app/core/signals/types

import backend/activity as backend_activity

import app_service/common/conversion
import app_service/common/types
import app_service/service/currency/service as currency_service
import app_service/service/transaction/service as transaction_service
import app_service/service/token/service as token_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/saved_address/service as saved_address_service
import app_service/service/network/service as network_service

import app/modules/shared_models/currency_amount

proc toRef*[T](obj: T): ref T =
  new(result)
  result[] = obj

const FETCH_BATCH_COUNT_DEFAULT = 10
const FETCH_RECIPIENTS_BATCH_COUNT_DEFAULT = 2000
const FETCH_COLLECTIBLES_BATCH_COUNT_DEFAULT = 2000

QtObject:
  type
    Controller* = ref object of QObject
      model: Model

      recipientsModel: RecipientsModel
      collectiblesModel: CollectiblesModel
      currentActivityFilter: backend_activity.ActivityFilter
      currencyService: currency_service.Service
      tokenService: token_service.Service
      savedAddressService: saved_address_service.Service
      networkService: network_service.Service

      eventsHandler: EventsHandler
      status: Status

      # call updateAssetsIdentities after updating filterTokenCodes
      filterTokenCodes: HashSet[string]

      addresses: seq[string]
      # call updateAssetsIdentities after updating chainIds
      chainIds: seq[int]

  proc setup(self: Controller)
  proc delete*(self: Controller)
  proc setupEventHandlers(self: Controller, events: EventEmitter)
  proc newController*(currencyService: currency_service.Service,
                      tokenService: token_service.Service,
                      savedAddressService: saved_address_service.Service,
                      networkService: network_service.Service,
                      events: EventEmitter): Controller =
    new(result, delete)

    result.model = newModel()
    result.recipientsModel = newRecipientsModel()
    result.collectiblesModel = newCollectiblesModel()
    result.tokenService = tokenService
    result.savedAddressService = savedAddressService
    result.networkService = networkService
    result.currentActivityFilter = backend_activity.getIncludeAllActivityFilter()

    result.eventsHandler = newEventsHandler(events)
    result.status = newStatus()

    result.currencyService = currencyService

    result.filterTokenCodes = initHashSet[string]()

    result.addresses = @[]
    result.chainIds = @[]

    result.setup()

    result.setupEventHandlers(events)

  proc getModel*(self: Controller): QAbstractListModel {.slot.} =
    return self.model

  QtProperty[QAbstractListModel] model:
    read = getModel

  proc getRecipientsModel*(self: Controller): QAbstractListModel {.slot.} =
    return self.recipientsModel

  QtProperty[QAbstractListModel] recipientsModel:
    read = getRecipientsModel

  proc getCollectiblesModel*(self: Controller): QAbstractListModel {.slot.} =
    return self.collectiblesModel

  QtProperty[QAbstractListModel] collectiblesModel:
    read = getCollectiblesModel

  proc backendToPresentation(self: Controller, backendEntities: seq[backend_activity.ActivityEntry]): seq[entry.ActivityEntry] =
    for backendEntry in backendEntities:
      let ae = entry.newActivityEntry(backendEntry, self.addresses, self.currencyService)
      result.add(ae)

  proc processResponse(self: Controller, response: JsonNode) =
    defer: self.status.setLoadingData(false)

    let res = fromJson(response, backend_activity.FilterResponse)

    defer: self.status.setErrorCode(res.errorCode.int)

    if res.errorCode != ErrorCodeSuccess:
      error "error fetching activity entries: ",code = res.errorCode
      return

    let entries = self.backendToPresentation(res.activities)

    self.model.setEntries(entries, res.offset, res.hasMore)

    if res.offset == 0:
      self.status.setNewDataAvailable(false)

  proc sessionId(self: Controller): int32 =
    return self.eventsHandler.getSessionId()

  proc invalidateData(self: Controller) =
    self.status.setLoadingData(true)
    self.status.setIsFilterDirty(false)

    self.model.resetModel(@[])

    self.status.setNewDataAvailable(false)


  # Stops the old session and starts a new one. All the incremental changes are lost
  proc newFilterSession*(self: Controller) {.slot.} =
    self.invalidateData()

    # stop the previous filter session
    if self.eventsHandler.hasSessionId():
      let res = backend_activity.stopActivityFilterSession(self.sessionId())
      if res.error != nil:
        error "error stopping the previous session of activity fitlering: ", error = res.error
      self.eventsHandler.clearSessionId()

    # start a new filter session
    let (sessionId, ok) = backend_activity.newActivityFilterSession(self.addresses, seq[backend_activity.ChainId](self.chainIds), self.currentActivityFilter, FETCH_BATCH_COUNT_DEFAULT)
    if not ok:
      self.status.setLoadingData(false)
      return

    self.eventsHandler.setSessionId(sessionId)

  proc updateFilter*(self: Controller) {.slot.} =
    self.invalidateData()

    if not backend_activity.updateFilterForSession(self.sessionId(), self.currentActivityFilter):
      self.status.setLoadingData(false)
      error "error updating activity filter"
      return

  proc resetActivityData*(self: Controller) {.slot.} =
    self.invalidateData()

    let response = backend_activity.resetActivityFilterSession(self.sessionId())
    if response.error != nil:
      self.status.setLoadingData(false)
      error "error fetching activity entries from start: ", error = response.error
      return

  proc loadMoreItems(self: Controller) {.slot.} =
    self.status.setLoadingData(true)

    let response = backend_activity.getMoreForActivityFilterSession(self.sessionId())
    if response.error != nil:
      self.status.setLoadingData(false)
      error "error fetching more activity entries: ", error = response.error
      return

  proc updateCollectiblesModel*(self: Controller) {.slot.} =
    self.status.setLoadingCollectibles(true)
    let res = backend_activity.getActivityCollectiblesAsync(self.sessionId(), self.chainIds, self.addresses, 0, FETCH_COLLECTIBLES_BATCH_COUNT_DEFAULT)
    if res.error != nil:
      self.status.setLoadingCollectibles(false)
      error "error fetching collectibles: ", error = res.error
      return

  proc loadMoreCollectibles*(self: Controller) {.slot.} =
    self.status.setLoadingCollectibles(true)
    let res = backend_activity.getActivityCollectiblesAsync(self.sessionId(), self.chainIds, self.addresses, self.collectiblesModel.getCount(), FETCH_COLLECTIBLES_BATCH_COUNT_DEFAULT)
    if res.error != nil:
      self.status.setLoadingCollectibles(false)
      error "error fetching collectibles: ", error = res.error
      return

  proc resetFilter*(self: Controller) {.slot.} =
    self.currentActivityFilter = backend_activity.getIncludeAllActivityFilter()

  proc setFilterTime*(self: Controller, startTimestamp: int, endTimestamp: int) {.slot.} =
    self.currentActivityFilter.period = backend_activity.newPeriod(startTimestamp, endTimestamp)

  proc setFilterType*(self: Controller, typesArrayJsonString: string) {.slot.} =
    let typesJson = parseJson(typesArrayJsonString)
    if typesJson.kind != JArray:
      error "invalid array of json ints"
      return

    var types = newSeq[backend_activity.ActivityType](typesJson.len)
    for i in 0 ..< typesJson.len:
      types[i] = backend_activity.ActivityType(typesJson[i].getInt())

    self.currentActivityFilter.types = types

  # Call this method on every data update (ideally only if updates are before the last timestamp retrieved)
  # This depends on self.addresses being set, call on every address change
  proc updateStartTimestamp*(self: Controller) {.slot.} =
    self.status.setLoadingStartTimestamp(true)

    let resJson = backend_activity.getOldestActivityTimestampAsync(self.sessionId(), self.addresses)
    if resJson.error != nil:
      self.status.setLoadingStartTimestamp(false)
      error "error requesting oldest activity timestamp: ", error = resJson.error
      return

  proc checkAllSavedAddresses(self: Controller) =
    let appNetwork = self.savedAddressService.areTestNetworksEnabled()
    let addressesToSearchThrough = self.savedAddressService.getSavedAddresses().filter(x => x.isTest == appNetwork)
    for saDto in addressesToSearchThrough:
      self.model.refreshItemsContainingAddress(saDto.address)

  proc setupEventHandlers(self: Controller, events: EventEmitter) =
    # setup in app direct event handlers
    events.on(SIGNAL_WALLET_ACCOUNT_NETWORK_ENABLED_UPDATED) do(e:Args):
      self.checkAllSavedAddresses()

    events.on(SIGNAL_SAVED_ADDRESSES_UPDATED) do(e:Args):
      self.checkAllSavedAddresses()

    events.on(SIGNAL_SAVED_ADDRESS_UPDATED) do(e:Args):
      let args = SavedAddressArgs(e)
      self.model.refreshItemsContainingAddress(args.address)

    events.on(SIGNAL_SAVED_ADDRESS_DELETED) do(e:Args):
      let args = SavedAddressArgs(e)
      self.model.refreshItemsContainingAddress(args.address)

    events.on(SIGNAL_TOKENS_LIST_UPDATED) do(e:Args):
      self.model.refreshAmountCurrency(self.currencyService)

    # setup other event handlers
    self.eventsHandler.onFilteringDone(proc (jsonObj: JsonNode) =
      self.processResponse(jsonObj)
    )

    self.eventsHandler.onFilteringUpdateDone(proc (jn: JsonNode) =
      if jn.kind != JArray:
        error "expected an array"

      var entries = newSeq[backend_activity.Data](jn.len)
      for i in 0 ..< jn.len:
        entries[i] = fromJson(jn[i], backend_activity.Data)

      self.model.updateEntries(entries)
    )

    self.eventsHandler.onFilteringSessionUpdated(proc (jn: JsonNode) =
      if jn.kind != JObject:
        error "expected an object"
        return

      let res = fromJson(jn, backend_activity.SessionUpdate)

      var updated = newSeq[backend_activity.ActivityEntry](len(res.`new`))
      var indices = newSeq[int](len(res.`new`))
      for i in 0 ..< len(res.`new`):
        updated[i] = res.`new`[i].entry
        indices[i] = res.`new`[i].pos

      self.status.setNewDataAvailable(res.hasNewOnTop)
      if len(res.`new`) > 0:
        let entries = self.backendToPresentation(updated)
        self.model.addNewEntries(entries, indices)
    )

    self.eventsHandler.onGetRecipientsDone(proc (jsonObj: JsonNode) =
      defer: self.status.setLoadingRecipients(false)
      let res = fromJson(jsonObj, backend_activity.GetRecipientsResponse)

      if res.errorCode != ErrorCodeSuccess:
        error "error fetching recipients: ", code = res.errorCode
        return

      self.recipientsModel.addAddresses(res.addresses, res.offset, res.hasMore)
    )

    self.eventsHandler.onGetOldestTimestampDone(proc (jsonObj: JsonNode) =
      defer: self.status.setLoadingStartTimestamp(false)
      let res = fromJson(jsonObj, backend_activity.GetOldestTimestampResponse)

      if res.errorCode != ErrorCodeSuccess:
        error "error fetching start timestamp: ", code = res.errorCode
        return

      self.status.setStartTimestamp(res.timestamp)
    )

    self.eventsHandler.onGetCollectiblesDone(proc (jsonObj: JsonNode) =
      defer: self.status.setLoadingCollectibles(false)
      let res = fromJson(jsonObj, backend_activity.GetCollectiblesResponse)

      if res.errorCode != ErrorCodeSuccess:
        error "error fetching collectibles: ", code = res.errorCode
        return

      try:
        let items = res.collectibles.map(header => collectibleToItem(header))
        self.collectiblesModel.setItems(items, res.offset, res.hasMore)
      except Exception as e:
        error "Error converting activity entries: ", code = e.msg
    )

  proc setFilterStatus*(self: Controller, statusesArrayJsonString: string) {.slot.} =
    let statusesJson = parseJson(statusesArrayJsonString)
    if statusesJson.kind != JArray:
      error "invalid array of json ints"
      return

    var statuses = newSeq[backend_activity.ActivityStatus](statusesJson.len)
    for i in 0 ..< statusesJson.len:
      statuses[i] = backend_activity.ActivityStatus(statusesJson[i].getInt())

    self.currentActivityFilter.statuses = statuses

  proc setFilterToAddresses*(self: Controller, addressesArrayJsonString: string) {.slot.} =
    let addressesJson = parseJson(addressesArrayJsonString)
    if addressesJson.kind != JArray:
      error "invalid array of json strings"
      return

    var addresses = newSeq[string](addressesJson.len)
    for i in 0 ..< addressesJson.len:
      addresses[i] = addressesJson[i].getStr()

    self.currentActivityFilter.counterpartyAddresses = addresses

  proc setFilterCollectibles*(self: Controller, collectiblesArrayJsonString: string) {.slot.} =
    let collectiblesJson = parseJson(collectiblesArrayJsonString)
    if collectiblesJson.kind != JArray:
      error "invalid array of json strings"
      return

    var collectibles = newSeq[backend_activity.Token]()
    for i in 0 ..< collectiblesJson.len:
      let uid = collectiblesJson[i].getStr()
      # TODO: We need the token type here, which is not part of the uid.
      # We currently don't support filtering ERC1155 tokens anyway, so it's not an issue.
      # When we have a split model for all collectibles metadata, get the entry from there
      # to get the token type. Perhaps also add an "UnknownCollectible" TokenType that includes
      # both ERC721 and ERC1155?
      collectibles.add(collectibleUidToActivityToken(uid, TokenType.ERC721))

    self.currentActivityFilter.collectibles = collectibles

  # Depends on self.filterTokenCodes and self.chainIds, so should be called after updating them
  proc updateAssetsIdentities(self: Controller) =
    var assets = newSeq[backend_activity.Token]()
    for tokenCode in self.filterTokenCodes:
      for chainId in self.chainIds:
        let network = self.networkService.getNetworkByChainId(chainId)
        if network == nil:
          error "network not found for chainId: ", chainId
          continue

        let token = self.tokenService.getTokenByKey(tokenCode)
        if token.isNil:
          continue
        let tokenType = if token.isNative: TokenType.Native else: TokenType.ERC20
        assets.add(backend_activity.Token(
          tokenType: tokenType,
          chainId: backend_activity.ChainId(token.chainId),
          address: some(decodeHexAddress(token.address))
        ))

    self.currentActivityFilter.assets = assets

  proc setFilterAssets*(self: Controller, assetsArrayJsonString: string, excludeAssets: bool) {.slot.} =
    self.filterTokenCodes.clear()
    if excludeAssets:
      return

    let assetsJson = parseJson(assetsArrayJsonString)
    if assetsJson.kind != JArray:
      error "invalid array of json strings"
      return

    for i in 0 ..< assetsJson.len:
      let tokenCode = assetsJson[i].getStr()
      self.filterTokenCodes.incl(tokenCode)

    self.updateAssetsIdentities()

  # Requires self.newFilterSession() to be called after this
  proc setFilterAddresses*(self: Controller, addresses: seq[string]) =
    self.addresses = addresses
    self.status.setIsFilterDirty(true)

  proc setFilterAddressesJson*(self: Controller, jsonArray: string) {.slot.}  =
    let addressesJson = parseJson(jsonArray)
    if addressesJson.kind != JArray:
      error "invalid array of json strings"
      return

    var addresses = newSeq[string]()
    for i in 0 ..< addressesJson.len:
      if addressesJson[i].kind != JString:
        error "not string entry in the addresses json array for index ", i
        return
      addresses.add(addressesJson[i].getStr())

    self.setFilterAddresses(addresses)

    # Every change of addresses have to start a new session to get incremental updates when filter is cleared
    self.newFilterSession()

  proc setFilterToAddresses*(self: Controller, addresses: seq[string]) =
    self.currentActivityFilter.counterpartyAddresses = addresses

  proc setFilterChains(self: Controller, chainIds: seq[int], allEnabled: bool) =
    self.chainIds = chainIds
    self.status.setIsFilterDirty(true)
    self.status.emitFilterChainsChanged()

    self.status.emitFilterChainsChanged()
    self.updateAssetsIdentities()

  proc setFilterChainsJson*(self: Controller, jsonArray: string, allChainsSelected: bool) {.slot.}  =
    let chainsJson = parseJson(jsonArray)
    if chainsJson.kind != JArray:
      error "invalid array of json ints"
      return

    var chains = newSeq[int]()
    for i in 0 ..< chainsJson.len:
      if chainsJson[i].kind != JInt:
        error "not int entry in the chains json array for index ", i
        return
      chains.add(chainsJson[i].getInt())

    self.setFilterChains(chains, allChainsSelected)

    # Every change of chains have to start a new session to get incremental updates when filter is cleared
    self.newFilterSession()

  proc updateRecipientsModel*(self: Controller) {.slot.} =
    self.status.setLoadingRecipients(true)
    # Recipients don't change with filers so we can use the same request id
    let res = backend_activity.getRecipientsAsync(self.sessionId(), self.chainIds, self.addresses, 0, FETCH_RECIPIENTS_BATCH_COUNT_DEFAULT)
    if res.error != nil or res.result.kind != JBool:
      self.status.setLoadingRecipients(false)
      error "error fetching recipients: ", error = res.error, kind = res.result.kind
      return

    # If the request was enqueued and already waiting for a response, we don't need to do anything
    if res.result.getBool():
      self.status.setLoadingRecipients(false)

  proc loadMoreRecipients(self: Controller) {.slot.} =
    self.status.setLoadingRecipients(true)
    # Recipients don't change with filers so we can use the same request id
    let res = backend_activity.getRecipientsAsync(self.sessionId(), self.chainIds, self.addresses, self.recipientsModel.getCount(), FETCH_RECIPIENTS_BATCH_COUNT_DEFAULT)
    if res.error != nil:
      self.status.setLoadingRecipients(false)
      error "error fetching more recipient entries: ", error = res.error
      return

    # If the request was enqueued and waiting for an answer, we don't need to do anything
    if res.result.getBool():
      self.status.setLoadingRecipients(false)

  proc getStatus*(self: Controller): QVariant {.slot.} =
    return newQVariant(self.status)

  QtProperty[QVariant] status:
    read = getStatus

  proc globalFilterChanged*(self: Controller, addresses: seq[string], chainIds: seq[int], allChainsEnabled: bool) =
    if (self.addresses == addresses and self.chainIds == chainIds):
      return

    self.setFilterAddresses(addresses)
    self.setFilterChains(chainIds, allChainsEnabled)

    # Every change of chains and addresses have to start a new session to get incremental updates when filter is cleared
    self.newFilterSession()

  proc noLimitTimestamp*(self: Controller): int {.slot.} =
    return backend_activity.noLimitTimestampForPeriod

  proc setup(self: Controller) =
    self.QObject.setup

  proc delete*(self: Controller) =
    self.QObject.delete

