import unittest, json, options, sequtils, times
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

proc collectibleIdJson(tokenId: int): JsonNode =
  %*{"contractID": {"chainID": ChainId, "address": ContractAddress}, "tokenID": $tokenId}

proc emitWalletEvent(events: EventEmitter, eventType: string, message: JsonNode,
    requestId = none(int), accounts: seq[string] = @[], chainID = 0) =
  let signal = WalletSignal(eventType: eventType, message: $message, requestId: requestId,
    accounts: accounts, chainID: chainID)
  signal.signalType = SignalType.Wallet
  events.emit(SignalType.Wallet.event, signal)

proc answerBatch(events: EventEmitter, offset: int, tokenIds: seq[int], hasMore: bool) =
  let collectibles = tokenIds.mapIt(%*{"data_type": CollectibleDataType.Header.int, "id": collectibleIdJson(it)})
  events.emitWalletEvent(eventOwnedCollectiblesFilteringDone,
    %*{"collectibles": collectibles, "offset": offset, "hasMore": hasMore, "errorCode": ErrorCodeSuccess.int},
    requestId = some(RequestId.int))

proc ownershipChangedWhileLoading(events: EventEmitter, tokenId: int) =
  events.emitWalletEvent(eventCollectiblesOwnershipUpdatePartial,
    %*{"added": [collectibleIdJson(tokenId)], "updated": [], "removed": []},
    accounts = @[Address], chainID = ChainId)
  let deadline = epochTime() + (RefreshDebounceMs + 200) / 1000
  while epochTime() < deadline:
    QCoreApplication.processEvents()

suite "collectibles controller single update load":
  setup:
    var requestedOffsets: seq[int] = @[]
    let events = createEventEmitter()
    let ctrl = newController(RequestId, nil, events, LoadType.AutoLoadSingleUpdate,
      fetchOwnedCollectibles = proc(requestId: int32, chainIds: seq[int], addresses: seq[string],
          filter: CollectibleFilter, offset: int, limit: int, dataType: CollectibleDataType,
          fetchCriteria: FetchCriteria): RpcResponse[JsonNode] =
        requestedOffsets.add(offset)
        RpcResponse[JsonNode](result: newJNull()))
    ctrl.setFilterAddressesAndChains(@[Address], @[ChainId])

  teardown:
    ctrl.delete()

  test "the list reaches the model while ownership keeps changing":
    check requestedOffsets == @[0]

    events.ownershipChangedWhileLoading(1)
    events.answerBatch(0, toSeq(1..50), hasMore = true)
    events.ownershipChangedWhileLoading(51)
    events.answerBatch(50, toSeq(51..100), hasMore = true)
    events.answerBatch(100, toSeq(101..120), hasMore = false)

    check ctrl.getModel().getCount() == 120
    # the refresh requested during the scan runs once the scan is applied
    check requestedOffsets == @[0, 50, 100, 0]

  test "a response that fails to parse doesn't block later fetches":
    events.emitWalletEvent(eventOwnedCollectiblesFilteringDone, %*{"collectibles": [], "hasMore": false},
      requestId = some(RequestId.int))
    ctrl.setFilterAddressesAndChains(@[Address], @[ChainId, 1])

    check requestedOffsets == @[0, 0]

  test "a collectible repeated by a shifted list is shown once":
    events.answerBatch(0, toSeq(1..50), hasMore = true)
    events.answerBatch(50, toSeq(46..95), hasMore = false)

    check ctrl.getModel().getCount() == 95
