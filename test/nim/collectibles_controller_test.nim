import unittest, json, options, sequtils, times
import stint
import nimqml
from seaqt/qcoreapplication import QCoreApplication, create, processEvents

import app/core/eventemitter
import app/core/signals/types
import app/modules/shared_modules/collectibles/controller
import app/modules/shared_models/collectibles_model
import backend/collectibles as backend_collectibles

discard QCoreApplication.create()  # the ownership refresh is debounced by a QTimer

const
  RequestId = 7'i32
  Address = "0x0000000000000000000000000000000000000001"
  ChainId = 421614
  ContractAddress = "0x00000000000000000000000000000000000000aa"
  RefreshDebounceMs = 1000
  BatchSize = 50

type OwnedRequest = tuple[offset: int, limit: int, dataType: CollectibleDataType]

proc collectibleIdJson(tokenId: int): JsonNode =
  %*{"contractID": {"chainID": ChainId, "address": ContractAddress}, "tokenID": $tokenId}

proc collectiblesJson(tokenIds: seq[int], dataType: CollectibleDataType): JsonNode =
  %tokenIds.mapIt(%*{"data_type": dataType.int, "id": collectibleIdJson(it)})

proc emitWalletEvent(events: EventEmitter, eventType: string, message: JsonNode,
    requestId = none(int), accounts: seq[string] = @[], chainID = 0) =
  let signal = WalletSignal(eventType: eventType, message: $message, requestId: requestId,
    accounts: accounts, chainID: chainID)
  signal.signalType = SignalType.Wallet
  events.emit(SignalType.Wallet.event, signal)

proc answerOwned(events: EventEmitter, offset: int, tokenIds: seq[int], hasMore: bool,
    dataType: CollectibleDataType) =
  events.emitWalletEvent(eventOwnedCollectiblesFilteringDone,
    %*{"collectibles": collectiblesJson(tokenIds, dataType), "offset": offset, "hasMore": hasMore,
      "errorCode": ErrorCodeSuccess.int},
    requestId = some(RequestId.int))

proc answerSnapshot(events: EventEmitter, tokenIds: seq[int]) =
  events.answerOwned(0, tokenIds, hasMore = false, CollectibleDataType.UniqueID)

proc answerDetails(events: EventEmitter, tokenIds: seq[int]) =
  events.emitWalletEvent(eventGetCollectiblesDetailsDone,
    %*{"collectibles": collectiblesJson(tokenIds, CollectibleDataType.Header),
      "errorCode": ErrorCodeSuccess.int},
    requestId = some(RequestId.int))

proc ownershipChangedWhileLoading(events: EventEmitter, tokenId: int) =
  events.emitWalletEvent(eventCollectiblesOwnershipUpdatePartial,
    %*{"added": [collectibleIdJson(tokenId)], "updated": [], "removed": []},
    accounts = @[Address], chainID = ChainId)
  let deadline = epochTime() + (RefreshDebounceMs + 200) / 1000
  while epochTime() < deadline:
    QCoreApplication.processEvents()

template withController(loadType: LoadType, body: untyped) =
  var ownedRequests {.inject.}: seq[OwnedRequest] = @[]
  var detailsRequests {.inject.}: seq[seq[int]] = @[]
  let events {.inject.} = createEventEmitter()
  let ctrl {.inject.} = newController(RequestId, nil, events, loadType, calls = CollectiblesCalls(
    fetchOwned: proc(requestId: int32, chainIds: seq[int], addresses: seq[string],
        filter: CollectibleFilter, offset: int, limit: int, dataType: CollectibleDataType,
        fetchCriteria: FetchCriteria): RpcResponse[JsonNode] =
      ownedRequests.add((offset, limit, dataType))
      RpcResponse[JsonNode](result: newJNull()),
    fetchByUniqueId: proc(requestId: int32, uniqueIds: seq[CollectibleUniqueID],
        dataType: CollectibleDataType): RpcResponse[JsonNode] =
      detailsRequests.add(uniqueIds.mapIt(it.tokenId.truncate(int)))
      RpcResponse[JsonNode](result: newJNull())))
  ctrl.setFilterAddressesAndChains(@[Address], @[ChainId])
  try:
    body
  finally:
    ctrl.delete()

suite "collectibles controller single update load":
  test "reads one snapshot of IDs, then the details of those IDs in batches":
    withController(LoadType.AutoLoadSingleUpdate):
      check ownedRequests.len == 1
      check ownedRequests[0].offset == 0
      check ownedRequests[0].limit > 1000
      check ownedRequests[0].dataType == CollectibleDataType.UniqueID

      events.answerSnapshot(toSeq(1..120))
      check detailsRequests == @[toSeq(1..50)]
      events.answerDetails(toSeq(1..50))
      check detailsRequests[^1] == toSeq(51..100)
      events.answerDetails(toSeq(51..100))
      check detailsRequests[^1] == toSeq(101..120)
      check ctrl.getModel().getCount() == 0   # applied once, at the end
      events.answerDetails(toSeq(101..120))

      check ctrl.getModel().getCount() == 120
      check ownedRequests.len == 1
      check detailsRequests.len == 3

  test "the list reaches the model while ownership keeps changing":
    withController(LoadType.AutoLoadSingleUpdate):
      events.ownershipChangedWhileLoading(1)
      events.answerSnapshot(toSeq(1..120))
      events.ownershipChangedWhileLoading(51)
      events.answerDetails(toSeq(1..50))
      events.answerDetails(toSeq(51..100))
      events.answerDetails(toSeq(101..120))

      check ctrl.getModel().getCount() == 120
      check detailsRequests.len == 3
      # the refresh requested during the scan runs once, after the scan is applied
      check ownedRequests.len == 2

  test "an empty snapshot empties the list without reading details":
    withController(LoadType.AutoLoadSingleUpdate):
      events.answerSnapshot(@[])

      check ctrl.getModel().getCount() == 0
      check not ctrl.getModel().getIsFetching()
      check detailsRequests.len == 0

  test "a response that fails to parse doesn't block later fetches":
    withController(LoadType.AutoLoadSingleUpdate):
      events.emitWalletEvent(eventOwnedCollectiblesFilteringDone, %*{"collectibles": [], "hasMore": false},
        requestId = some(RequestId.int))
      ctrl.setFilterAddressesAndChains(@[Address], @[ChainId, 1])

      check ownedRequests.len == 2

suite "collectibles controller paginated load":
  test "reads headers by offset and appends each batch":
    withController(LoadType.AutoLoadPaginated):
      check ownedRequests == @[(0, BatchSize, CollectibleDataType.Header)]
      events.answerOwned(0, toSeq(1..50), hasMore = true, CollectibleDataType.Header)
      check ctrl.getModel().getCount() == 50
      check ownedRequests[^1] == (50, BatchSize, CollectibleDataType.Header)
      check detailsRequests.len == 0
