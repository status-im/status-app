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
const SIGNAL_WC_SESSION_PROPOSAL* = "WCSessionProposal"
const SIGNAL_WC_SESSION_REQUEST* = "WCSessionRequest"
const SIGNAL_WC_SESSION_DELETE* = "WCSessionDelete"
const SIGNAL_WC_PAIR_RESULT* = "WCPairResult"
const SIGNAL_WC_APPROVE_SESSION_RESULT* = "WCApproveSessionResult"
const SIGNAL_WC_REJECT_SESSION_RESULT* = "WCRejectSessionResult"
const SIGNAL_WC_SESSION_REQUEST_ANSWER_RESULT* = "WCSessionRequestAnswerResult"
const SIGNAL_WC_EMIT_EVENT_RESULT* = "WCEmitEventResult"
const SIGNAL_WC_GET_ACTIVE_SESSIONS_RESULT* = "WCGetActiveSessionsResult"
const SIGNAL_WC_DISCONNECT_SESSION_RESULT* = "WCDisconnectSessionResult"

# Enum with events
type Event* = enum
  DappConnect

type ConnectorCallRPCResultArgs* = ref object of Args
  requestId*: int
  payload*: string

type WCAsyncResultArgs* = ref object of Args
  requestId*: string
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
    self.events.on(SignalType.WCSessionProposal.event, proc(e: Args) =
      if self.eventHandler == nil:
        return
      try:
        let data = WCSessionProposalSignal(e)
        self.events.emit(SIGNAL_WC_SESSION_PROPOSAL, data)
      except Exception as ex:
        error "failed to process WCSessionProposal", error=ex.msg, exceptionName=ex.name
    )
    self.events.on(SignalType.WCSessionRequest.event, proc(e: Args) =
      if self.eventHandler == nil:
        return
      try:
        let data = WCSessionRequestSignal(e)
        self.events.emit(SIGNAL_WC_SESSION_REQUEST, data)
      except Exception as ex:
        error "failed to process WCSessionRequest", error=ex.msg, exceptionName=ex.name
    )
    self.events.on(SignalType.WCSessionDelete.event, proc(e: Args) =
      try:
        let data = WCSessionDeleteSignal(e)
        self.events.emit(SIGNAL_WC_SESSION_DELETE, data)
      except Exception as ex:
        error "failed to process WCSessionDelete", error=ex.msg, exceptionName=ex.name
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

  proc emitWCAsyncResult*(self: Service, signalName: string, responseObj: JsonNode) =
    var data = WCAsyncResultArgs()
    data.requestId = responseObj{"requestId"}.getStr("")
    data.payload = $responseObj
    self.events.emit(signalName, data)

  proc onPairWalletConnectResolved*(self: Service, response: string) {.slot.} =
    try:
      self.emitWCAsyncResult(SIGNAL_WC_PAIR_RESULT, response.parseJson)
    except Exception as e:
      error "onPairWalletConnectResolved failed", error=e.msg

  proc onApproveWCSessionResolved*(self: Service, response: string) {.slot.} =
    try:
      self.emitWCAsyncResult(SIGNAL_WC_APPROVE_SESSION_RESULT, response.parseJson)
    except Exception as e:
      error "onApproveWCSessionResolved failed", error=e.msg

  proc onRejectWCSessionResolved*(self: Service, response: string) {.slot.} =
    try:
      self.emitWCAsyncResult(SIGNAL_WC_REJECT_SESSION_RESULT, response.parseJson)
    except Exception as e:
      error "onRejectWCSessionResolved failed", error=e.msg

  proc onApproveWCSessionRequestResolved*(self: Service, response: string) {.slot.} =
    try:
      self.emitWCAsyncResult(SIGNAL_WC_SESSION_REQUEST_ANSWER_RESULT, response.parseJson)
    except Exception as e:
      error "onApproveWCSessionRequestResolved failed", error=e.msg

  proc onRejectWCSessionRequestResolved*(self: Service, response: string) {.slot.} =
    try:
      self.emitWCAsyncResult(SIGNAL_WC_SESSION_REQUEST_ANSWER_RESULT, response.parseJson)
    except Exception as e:
      error "onRejectWCSessionRequestResolved failed", error=e.msg

  proc onEmitWCSessionEventResolved*(self: Service, response: string) {.slot.} =
    try:
      self.emitWCAsyncResult(SIGNAL_WC_EMIT_EVENT_RESULT, response.parseJson)
    except Exception as e:
      error "onEmitWCSessionEventResolved failed", error=e.msg

  proc onGetWCActiveSessionsResolved*(self: Service, response: string) {.slot.} =
    try:
      self.emitWCAsyncResult(SIGNAL_WC_GET_ACTIVE_SESSIONS_RESULT, response.parseJson)
    except Exception as e:
      error "onGetWCActiveSessionsResolved failed", error=e.msg

  proc onDisconnectWCSessionResolved*(self: Service, response: string) {.slot.} =
    try:
      self.emitWCAsyncResult(SIGNAL_WC_DISCONNECT_SESSION_RESULT, response.parseJson)
    except Exception as e:
      error "onDisconnectWCSessionResolved failed", error=e.msg

  proc pairWalletConnectAsync*(self: Service, requestId: string, uri: string) =
    try:
      let arg = PairWalletConnectTaskArg(
        tptr: pairWalletConnectTask,
        vptr: cast[uint](self.vptr),
        slot: "onPairWalletConnectResolved",
        requestId: requestId,
        uri: uri
      )
      self.threadpool.start(arg)
    except Exception as e:
      error "pairWalletConnectAsync failed to enqueue", requestId=requestId, error=e.msg
      self.emitWCAsyncResult(SIGNAL_WC_PAIR_RESULT, %* {"requestId": requestId, "ok": false, "error": e.msg})

  proc disconnectWCSessionAsync*(self: Service, requestId: string, topic: string) =
    try:
      let arg = DisconnectWCSessionTaskArg(
        tptr: disconnectWCSessionTask,
        vptr: cast[uint](self.vptr),
        slot: "onDisconnectWCSessionResolved",
        requestId: requestId,
        topic: topic
      )
      self.threadpool.start(arg)
    except Exception as e:
      error "disconnectWCSessionAsync failed to enqueue", requestId=requestId, error=e.msg
      self.emitWCAsyncResult(SIGNAL_WC_DISCONNECT_SESSION_RESULT, %* {"requestId": requestId, "topic": topic, "ok": false, "error": e.msg})

  proc getWCActiveSessionsAsync*(self: Service, requestId: string, validAtTimestamp: int64) =
    try:
      let arg = GetWCActiveSessionsTaskArg(
        tptr: getWCActiveSessionsTask,
        vptr: cast[uint](self.vptr),
        slot: "onGetWCActiveSessionsResolved",
        requestId: requestId,
        validAtTimestamp: validAtTimestamp
      )
      self.threadpool.start(arg)
    except Exception as e:
      error "getWCActiveSessionsAsync failed to enqueue", requestId=requestId, error=e.msg
      self.emitWCAsyncResult(SIGNAL_WC_GET_ACTIVE_SESSIONS_RESULT, %* {"requestId": requestId, "validAtTimestamp": validAtTimestamp, "sessionsJson": "[]", "ok": false, "error": e.msg})

  proc approveWCSessionRequestAsync*(self: Service, requestId: string, topic, sessionRequestId, signature: string) =
    try:
      let arg = ApproveWCSessionRequestTaskArg(
        tptr: approveWCSessionRequestTask,
        vptr: cast[uint](self.vptr),
        slot: "onApproveWCSessionRequestResolved",
        requestId: requestId,
        topic: topic,
        sessionRequestId: sessionRequestId,
        signature: signature
      )
      self.threadpool.start(arg)
    except Exception as e:
      error "approveWCSessionRequestAsync failed to enqueue", requestId=requestId, error=e.msg
      self.emitWCAsyncResult(SIGNAL_WC_SESSION_REQUEST_ANSWER_RESULT, %* {"requestId": requestId, "topic": topic, "sessionRequestId": sessionRequestId, "accept": true, "ok": false, "error": e.msg})

  proc rejectWCSessionRequestAsync*(self: Service, requestId: string, topic, sessionRequestId: string) =
    try:
      let arg = RejectWCSessionRequestTaskArg(
        tptr: rejectWCSessionRequestTask,
        vptr: cast[uint](self.vptr),
        slot: "onRejectWCSessionRequestResolved",
        requestId: requestId,
        topic: topic,
        sessionRequestId: sessionRequestId
      )
      self.threadpool.start(arg)
    except Exception as e:
      error "rejectWCSessionRequestAsync failed to enqueue", requestId=requestId, error=e.msg
      self.emitWCAsyncResult(SIGNAL_WC_SESSION_REQUEST_ANSWER_RESULT, %* {"requestId": requestId, "topic": topic, "sessionRequestId": sessionRequestId, "accept": false, "ok": false, "error": e.msg})

  proc approveWCSessionAsync*(self: Service, requestId: string, proposalId, account: string, dappUrl, dappName, dappIcon: string, supportedChainsJson: string) =
    try:
      let arg = ApproveWCSessionTaskArg(
        tptr: approveWCSessionTask,
        vptr: cast[uint](self.vptr),
        slot: "onApproveWCSessionResolved",
        requestId: requestId,
        proposalId: proposalId,
        account: account,
        dappUrl: dappUrl,
        dappName: dappName,
        dappIcon: dappIcon,
        supportedChainsJson: supportedChainsJson
      )
      self.threadpool.start(arg)
    except Exception as e:
      error "approveWCSessionAsync failed to enqueue", requestId=requestId, error=e.msg
      self.emitWCAsyncResult(SIGNAL_WC_APPROVE_SESSION_RESULT, %* {"requestId": requestId, "proposalId": proposalId, "sessionJson": "", "ok": false, "error": e.msg})

  proc rejectWCSessionAsync*(self: Service, requestId: string, proposalId: string) =
    try:
      let arg = RejectWCSessionTaskArg(
        tptr: rejectWCSessionTask,
        vptr: cast[uint](self.vptr),
        slot: "onRejectWCSessionResolved",
        requestId: requestId,
        proposalId: proposalId
      )
      self.threadpool.start(arg)
    except Exception as e:
      error "rejectWCSessionAsync failed to enqueue", requestId=requestId, error=e.msg
      self.emitWCAsyncResult(SIGNAL_WC_REJECT_SESSION_RESULT, %* {"requestId": requestId, "proposalId": proposalId, "ok": false, "error": e.msg})

  proc emitWCSessionEventAsync*(self: Service, requestId: string, topic, name, dataJson, chainId: string) =
    try:
      let arg = EmitWCSessionEventTaskArg(
        tptr: emitWCSessionEventTask,
        vptr: cast[uint](self.vptr),
        slot: "onEmitWCSessionEventResolved",
        requestId: requestId,
        topic: topic,
        name: name,
        dataJson: dataJson,
        chainId: chainId
      )
      self.threadpool.start(arg)
    except Exception as e:
      error "emitWCSessionEventAsync failed to enqueue", requestId=requestId, error=e.msg
      self.emitWCAsyncResult(SIGNAL_WC_EMIT_EVENT_RESULT, %* {"requestId": requestId, "topic": topic, "name": name, "ok": false, "error": e.msg})

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

