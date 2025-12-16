import nimqml, chronicles, json

import backend/connector as status_go

import app/global/global_singleton

import app/core/eventemitter
import app/core/signals/types
import app/core/tasks/[qt, threadpool]

import strutils

logScope:
  topics = "connector-service"

include ./async_tasks

const SIGNAL_CONNECTOR_SEND_REQUEST_ACCOUNTS* = "ConnectorSendRequestAccounts"
const SIGNAL_CONNECTOR_EVENT_CONNECTOR_SEND_TRANSACTION* = "ConnectorSendTransaction"
const SIGNAL_CONNECTOR_GRANT_DAPP_PERMISSION* = "ConnectorGrantDAppPermission"
const SIGNAL_CONNECTOR_REVOKE_DAPP_PERMISSION* = "ConnectorRevokeDAppPermission"
const SIGNAL_CONNECTOR_EVENT_CONNECTOR_SIGN* = "ConnectorSign"
const SIGNAL_CONNECTOR_CALL_RPC_RESULT* = "ConnectorCallRPCResult"
const SIGNAL_CONNECTOR_DAPP_CHAIN_ID_SWITCHED* = "ConnectorDAppChainIdSwitched"
const SIGNAL_CONNECTOR_ACCOUNT_CHANGED* = "ConnectorAccountChanged"

# Enum with events
type Event* = enum
  DappConnect

type ConnectorCallRPCResultArgs* = ref object of Args
  requestId*: int
  payload*: string

# Event handler function
type EventHandlerFn* = proc(event: Event, payload: string)

# This can be ditched for now and process everything in the controller;
# However, it would be good to have the DB based calls async and this might be needed
QtObject:
  type Service* = ref object of QObject
    events: EventEmitter
    eventHandler: EventHandlerFn
    threadpool: ThreadPool

  proc delete*(self: Service)
  proc newService*(
    events: EventEmitter,
    threadpool: ThreadPool
  ): Service =
    new(result, delete)
    result.QObject.setup

    result.events = events
    result.threadpool = threadpool

  proc init*(self: Service) =
    self.events.on(SignalType.ConnectorSendRequestAccounts.event, proc(e: Args) =
      if self.eventHandler == nil:
        return

      var data = ConnectorSendRequestAccountsSignal(e)

      if data.requestId.len() == 0:
        error "ConnectorSendRequestAccountsSignal failed, requestId is empty"
        return

      self.events.emit(SIGNAL_CONNECTOR_SEND_REQUEST_ACCOUNTS, data)
    )
    self.events.on(SignalType.ConnectorSendTransaction.event, proc(e: Args) =
      if self.eventHandler == nil:
        return
 
      var data = ConnectorSendTransactionSignal(e)

      if data.requestId.len() == 0:
        error "ConnectorSendTransactionSignal failed, requestId is empty"
        return

      self.events.emit(SIGNAL_CONNECTOR_EVENT_CONNECTOR_SEND_TRANSACTION, data)
    )
    self.events.on(SignalType.ConnectorGrantDAppPermission.event, proc(e: Args) =
      if self.eventHandler == nil:
        return

      var data = ConnectorGrantDAppPermissionSignal(e)

      self.events.emit(SIGNAL_CONNECTOR_GRANT_DAPP_PERMISSION, data)
    )
    self.events.on(SignalType.ConnectorRevokeDAppPermission.event, proc(e: Args) =
      if self.eventHandler == nil:
        return

      var data = ConnectorRevokeDAppPermissionSignal(e)

      self.events.emit(SIGNAL_CONNECTOR_REVOKE_DAPP_PERMISSION, data)
    )
    self.events.on(SignalType.ConnectorSign.event, proc(e: Args) =
      if self.eventHandler == nil:
        return

      var data = ConnectorSignSignal(e)

      debug "ConnectorSign received", requestId=data.requestId, requestIdLen=data.requestId.len()
      
      if data.requestId.len() == 0:
        error "ConnectorSignSignal failed, requestId is empty"
        return

      debug "ConnectorSign emitting signal", requestId=data.requestId
      self.events.emit(SIGNAL_CONNECTOR_EVENT_CONNECTOR_SIGN, data)
    )
    self.events.on(SignalType.ConnectorDAppChainIdSwitched.event, proc(e: Args) =
      if self.eventHandler == nil:
        return

      try:
        var data = ConnectorDAppChainIdSwitchedSignal(e)
        self.events.emit(SIGNAL_CONNECTOR_DAPP_CHAIN_ID_SWITCHED, data)
      except Exception as ex:
        error "failed to process ConnectorDAppChainIdSwitched", error=ex.msg, exceptionName=ex.name
    )
    self.events.on(SignalType.ConnectorAccountChanged.event, proc(e: Args) =
      if self.eventHandler == nil:
        return

      try:
        var data = ConnectorAccountChangedSignal(e)
        self.events.emit(SIGNAL_CONNECTOR_ACCOUNT_CHANGED, data)
      except Exception as ex:
        error "failed to process ConnectorAccountChanged", error=ex.msg, exceptionName=ex.name
    )

  proc registerEventsHandler*(self: Service, handler: EventHandlerFn) =
    self.eventHandler = handler

  proc approveDappConnect*(self: Service, requestId: string, account: string, chainID: uint): bool =
    try:
      var args = RequestAccountsAcceptedArgs()

      args.requestId = requestId
      args.account = account
      args.chainId = chainId
      
      return status_go.requestAccountsAcceptedFinishedRpc(args)

    except Exception as e:
      error "requestAccountsAcceptedFinishedRpc failed: ", err=e.msg
      return false
  
  proc approveTransactionRequest*(self: Service, requestId: string, hash: string): bool =
    try:
      var args = SendTransactionAcceptedArgs()

      args.requestId = requestId
      args.hash = hash

      return status_go.sendTransactionAcceptedFinishedRpc(args)

    except Exception as e:
      error "sendTransactionAcceptedFinishedRpc failed: ", err=e.msg
      return false

  proc rejectRequest*(self: Service, requestId: string, rpcCall: proc(args: RejectedArgs): bool, message: static[string]): bool =
    try:
      var args = RejectedArgs()
      args.requestId = requestId

      return rpcCall(args)

    except Exception as e:
      error message, err=e.msg
      return false

  proc rejectTransactionSigning*(self: Service, requestId: string): bool =
    rejectRequest(self, requestId, status_go.sendTransactionRejectedFinishedRpc, "sendTransactionRejectedFinishedRpc failed: ")

  proc rejectDappConnect*(self: Service, requestId: string): bool =
    rejectRequest(self, requestId, status_go.requestAccountsRejectedFinishedRpc, "requestAccountsRejectedFinishedRpc failed: ")

  proc recallDAppPermission*(self: Service, dAppUrl: string, clientId: string = ""): bool =
    try:
      return status_go.recallDAppPermissionFinishedRpc(dAppUrl, clientId)

    except Exception as e:
      error "recallDAppPermissionFinishedRpc failed: ", err=e.msg
      return false

  proc getDApps*(self: Service): string =
    try:
      let response = status_go.getPermittedDAppsList()
      if not response.error.isNil:
        raise newException(Exception, "Error getting connector dapp list: " & response.error.message)

      # Expect nil golang array to be valid empty array
      let jsonArray = $response.result
      return if jsonArray != "null": jsonArray else: "[]"
    except Exception as e:
      error "getDApps failed: ", err=e.msg
      return "[]"

  proc getDAppsByClientId*(self: Service, clientId: string): string =
    try:
      let response = status_go.getPermittedDAppsList()
      if not response.error.isNil:
        raise newException(Exception, "Error getting connector dapp list: " & response.error.message)
      
      let jsonArray = $response.result
      if jsonArray == "null":
        return "[]"
      
      # Parse and filter by clientId
      let allDapps = parseJson(jsonArray)
      var filteredDapps = newJArray()
      
      for dapp in allDapps:
        if dapp.hasKey("clientId") and dapp["clientId"].getStr() == clientId:
          filteredDapps.add(dapp)
      
      return $filteredDapps
    except Exception as e:
      error "getDAppsByClientId failed: ", err=e.msg
      return "[]"

  proc approveSignRequest*(self: Service, requestId: string, signature: string): bool =
    try:
      var args = SignAcceptedArgs()
      args.requestId = requestId
      args.signature = signature

      return status_go.sendSignAcceptedFinishedRpc(args)

    except Exception as e:
      error "sendSigAcceptedFinishedRpc failed: ", err=e.msg
      return false

  proc rejectSigning*(self: Service, requestId: string): bool =
    rejectRequest(self, requestId, status_go.sendSignRejectedFinishedRpc, "sendSignRejectedFinishedRpc failed: ")

  proc onConnectorCallRPCResolved*(self: Service, response: string) {.slot.} =
    try:
      let responseObj = response.parseJson
      let requestId = responseObj{"requestId"}.getInt(0)
      
      var data = ConnectorCallRPCResultArgs()
      data.requestId = requestId
      data.payload = response
      
      self.events.emit(SIGNAL_CONNECTOR_CALL_RPC_RESULT, data)
    except Exception as e:
      error "onConnectorCallRPCResolved failed", error=e.msg

  proc connectorCallRPC*(self: Service, requestId: int, message: string) =
    try:
      var messageJson: JsonNode
      try:
        messageJson = parseJson(message)
      except JsonParsingError as e:
        error "connectorCallRPC: invalid JSON message", requestId=requestId, error=e.msg, messagePreview=message[0..min(200, message.len-1)]
        return

      let arg = ConnectorCallRPCTaskArg(
        tptr: connectorCallRPCTask,
        vptr: cast[uint](self.vptr),
        slot: "onConnectorCallRPCResolved",
        requestId: requestId,
        message: messageJson
      )
      self.threadpool.start(arg)
    except Exception as e:
      error "connectorCallRPC: starting async background task failed", requestId=requestId, error=e.msg

  proc changeAccount*(self: Service, url: string, clientId: string, newAccount: string): bool =
    try:
      var args = ChangeAccountArgs(
        url: url,
        account: newAccount,
        clientID: clientId
      )
      
      return status_go.changeAccountFinishedRpc(args)

    except Exception as e:
      error "changeAccount failed", error=e.msg
      return false

  proc delete*(self: Service) =
    self.QObject.delete

