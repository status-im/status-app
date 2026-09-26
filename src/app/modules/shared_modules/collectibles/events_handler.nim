import nimqml, std/json, sequtils, strutils, options
import tables, sets

import app/core/eventemitter
import app/core/signals/types

import backend/collectibles as backend_collectibles

type EventCallbackProc = proc (eventObject: JsonNode)
type WalletEventCallbackProc = proc (data: WalletSignal)
type OwnershipUpdateCallbackProc = proc (address: string, chainID: int)
type OwnershipUpdateChangesCallbackProc = proc (address: string, chainID: int, changes: backend_collectibles.OwnershipUpdateMessage)

# EventsHandler responsible for catching collectibles related backend events and reporting them
QtObject:
  type
    EventsHandler* = ref object of QObject
      events: EventEmitter
      eventHandlers: Table[string, EventCallbackProc]
      walletEventHandlers: Table[string, WalletEventCallbackProc]

      subscribedAddresses: HashSet[string]
      subscribedChainIDs: HashSet[int]

      collectiblesOwnershipUpdateStartedFn: OwnershipUpdateCallbackProc
      collectiblesOwnershipUpdatePartialFn: OwnershipUpdateChangesCallbackProc
      collectiblesOwnershipUpdateFinishedFn: OwnershipUpdateChangesCallbackProc
      collectiblesOwnershipUpdateFinishedWithErrorFn: OwnershipUpdateCallbackProc

      requestId: int32

  proc setup(self: EventsHandler)
  proc delete*(self: EventsHandler)
  proc handleApiEvents(self: EventsHandler, e: Args)
  proc setupWalletEventHandlers(self: EventsHandler)
  proc newEventsHandler*(requestId: int32, events: EventEmitter): EventsHandler =
    new(result, delete)

    result.requestId = requestId

    result.events = events
    result.eventHandlers = initTable[string, EventCallbackProc]()

    result.setup()

    result.setupWalletEventHandlers()

    # Register for wallet events
    let eventsHandler = result
    result.events.on(SignalType.Wallet.event, proc(e: Args) =
        eventsHandler.handleApiEvents(e)
    )

  proc onOwnedCollectiblesFilteringDone*(self: EventsHandler, handler: EventCallbackProc) =
    self.eventHandlers[backend_collectibles.eventOwnedCollectiblesFilteringDone] = handler

  proc onGetCollectiblesDetailsDone*(self: EventsHandler, handler: EventCallbackProc) =
    self.eventHandlers[backend_collectibles.eventGetCollectiblesDetailsDone] = handler

  proc onCollectiblesDataUpdate*(self: EventsHandler, handler: EventCallbackProc) =
    self.eventHandlers[backend_collectibles.eventCollectiblesDataUpdated] = handler

  proc onCollectiblesOwnershipUpdateStarted*(self: EventsHandler, handler: OwnershipUpdateCallbackProc) =
    self.collectiblesOwnershipUpdateStartedFn = handler

  proc onCollectiblesOwnershipUpdatePartial*(self: EventsHandler, handler: OwnershipUpdateChangesCallbackProc) =
    self.collectiblesOwnershipUpdatePartialFn = handler

  proc onCollectiblesOwnershipUpdateFinished*(self: EventsHandler, handler: OwnershipUpdateChangesCallbackProc) =
    self.collectiblesOwnershipUpdateFinishedFn = handler

  proc onCollectiblesOwnershipUpdateFinishedWithError*(self: EventsHandler, handler: OwnershipUpdateCallbackProc) =
    self.collectiblesOwnershipUpdateFinishedWithErrorFn = handler

  proc handleApiEvents(self: EventsHandler, e: Args) =
    var data = WalletSignal(e)

    if data.requestId.isSome and data.requestId.get() != self.requestId:
      return

    if self.walletEventHandlers.hasKey(data.eventType):
      let callback = self.walletEventHandlers[data.eventType]
      callback(data)
    elif self.eventHandlers.hasKey(data.eventType):
      let callback = self.eventHandlers[data.eventType]
      let responseJson = parseJson(data.message)
      callback(responseJson)

  proc shouldIgnoreEvent(self: EventsHandler, data: WalletSignal): bool =
    if data.chainID in self.subscribedChainIDs:
      for address in data.accounts:
        if address in self.subscribedAddresses:
          return false
    return true

  proc setupWalletEventHandlers(self: EventsHandler) =
    self.walletEventHandlers[backend_collectibles.eventCollectiblesOwnershipUpdateStarted] = proc (data: WalletSignal) =
      if self.collectiblesOwnershipUpdateStartedFn == nil or self.shouldIgnoreEvent(data):
        return
      self.collectiblesOwnershipUpdateStartedFn(data.accounts[0], data.chainID)

    self.walletEventHandlers[backend_collectibles.eventCollectiblesOwnershipUpdatePartial] = proc (data: WalletSignal) =
      if self.collectiblesOwnershipUpdatePartialFn == nil or self.shouldIgnoreEvent(data):
        return
      let changesJson = parseJson(data.message)
      let changes = fromJson(changesJson, backend_collectibles.OwnershipUpdateMessage)
      self.collectiblesOwnershipUpdatePartialFn(data.accounts[0], data.chainID, changes)

    self.walletEventHandlers[backend_collectibles.eventCollectiblesOwnershipUpdateFinished] = proc (data: WalletSignal) =
      if self.collectiblesOwnershipUpdateFinishedFn == nil or self.shouldIgnoreEvent(data):
        return
      let changesJson = parseJson(data.message)
      let changes = fromJson(changesJson, backend_collectibles.OwnershipUpdateMessage)
      self.collectiblesOwnershipUpdateFinishedFn(data.accounts[0], data.chainID, changes)

    self.walletEventHandlers[backend_collectibles.eventCollectiblesOwnershipUpdateFinishedWithError] = proc (data: WalletSignal) =
      if self.collectiblesOwnershipUpdateFinishedWithErrorFn == nil or self.shouldIgnoreEvent(data):
        return
      self.collectiblesOwnershipUpdateFinishedWithErrorFn(data.accounts[0], data.chainID)
 
  proc updateSubscribedAddresses*(self: EventsHandler, addresses: seq[string]) =
    self.subscribedAddresses.clear()
    for address in addresses:
      self.subscribedAddresses.incl(address)

  proc updateSubscribedChainIDs*(self: EventsHandler, chainIDs: seq[int]) =
    self.subscribedChainIDs.clear()
    for chainID in chainIDs:
      self.subscribedChainIDs.incl(chainID)

  proc setup(self: EventsHandler) =
    self.QObject.setup

  proc delete*(self: EventsHandler) =
    self.QObject.delete

