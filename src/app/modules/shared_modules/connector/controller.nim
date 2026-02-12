import nimqml
import json, strutils
import chronicles, json_serialization
import app/core/eventemitter

import app/core/signals/types

import app_service/service/connector/service as connector_service

const SIGNAL_CONNECTOR_SEND_REQUEST_ACCOUNTS* = "ConnectorSendRequestAccounts"
const SIGNAL_CONNECTOR_EVENT_CONNECTOR_SEND_TRANSACTION* = "ConnectorSendTransaction"
const SIGNAL_CONNECTOR_GRANT_DAPP_PERMISSION* = "ConnectorGrantDAppPermission"
const SIGNAL_CONNECTOR_REVOKE_DAPP_PERMISSION* = "ConnectorRevokeDAppPermission"
const SIGNAL_CONNECTOR_SIGN* = "ConnectorSign"
const SIGNAL_CONNECTOR_CALL_RPC_RESULT* = "ConnectorCallRPCResult"
const SIGNAL_CONNECTOR_DAPP_CHAIN_ID_SWITCHED* = "ConnectorDAppChainIdSwitched"
const SIGNAL_CONNECTOR_ACCOUNT_CHANGED* = "ConnectorAccountChanged"

logScope:
  topics = "connector-controller"

QtObject:
  type
    Controller* = ref object of QObject
      service: connector_service.Service
      events: EventEmitter

  proc delete*(self: Controller)
  proc emitConnectRequested*(self: Controller, requestId: string, payload: string)
  proc emitConnected*(self: Controller, payload: string)
  proc emitDisconnected*(self: Controller, payload: string)
  proc emitSendTransaction*(self: Controller, requestId: string, payload: string)
  proc emitSign*(self: Controller, requestId: string, payload: string)
  proc emitConnectorCallRPCResult*(self: Controller, requestId: int, payload: string)
  proc emitChainIdSwitched*(self: Controller, payload: string)
  proc emitAccountChanged*(self: Controller, payload: string)
  proc wcSessionProposal*(self: Controller, requestId: string, uri: string, proposal: string)
  proc wcSessionRequest*(self: Controller, topic: string, requestId: string, requestJson: string)
  proc wcSessionDelete*(self: Controller, topic: string, dappUrl: string)

  proc newController*(service: connector_service.Service, events: EventEmitter): Controller =
    new(result, delete)

    result.events = events
    result.service = service

    let controller = result  # Capture result in a local variable

    service.registerEventsHandler(proc (event: connector_service.Event, payload: string) =
        discard
    )

    result.events.on(SIGNAL_CONNECTOR_SEND_REQUEST_ACCOUNTS) do(e: Args):
      let params = ConnectorSendRequestAccountsSignal(e)
      let dappInfo = %*{
        "icon": params.iconUrl,
        "name": params.name,
        "url": params.url,
      }

      controller.emitConnectRequested(params.requestId, dappInfo.toJson())

    result.events.on(SIGNAL_CONNECTOR_EVENT_CONNECTOR_SEND_TRANSACTION) do(e: Args):
      let params = ConnectorSendTransactionSignal(e)
      let dappInfo = %*{
        "icon": params.iconUrl,
        "name": params.name,
        "url": params.url,
        "chainId": params.chainId,
        "txArgs": params.txArgs,
      }

      controller.emitSendTransaction(params.requestId, dappInfo.toJson())

    result.events.on(SIGNAL_CONNECTOR_GRANT_DAPP_PERMISSION) do(e: Args):
      let params = ConnectorGrantDAppPermissionSignal(e)
      let dappInfo = %*{
        "icon": params.iconUrl,
        "name": params.name,
        "url": params.url,
        "chains": params.chains,
        "sharedAccount": params.sharedAccount,
        "clientId": params.clientId
      }

      controller.emitConnected(dappInfo.toJson())

    result.events.on(SIGNAL_CONNECTOR_REVOKE_DAPP_PERMISSION) do(e: Args):
      let params = ConnectorRevokeDAppPermissionSignal(e)
      let dappInfo = %*{
        "icon": params.iconUrl,
        "name": params.name,
        "url": params.url,
        "clientId": params.clientId
      }

      controller.emitDisconnected(dappInfo.toJson())

    result.events.on(SIGNAL_CONNECTOR_SIGN) do(e: Args):
      let params = ConnectorSignSignal(e)
      let dappInfo = %*{
        "icon": params.iconUrl,
        "name": params.name,
        "url": params.url,
        "challenge": params.challenge,
        "address": params.address,
        "method": params.signMethod,
      }

      controller.emitSign(params.requestId, dappInfo.toJson())

    result.events.on(SIGNAL_CONNECTOR_CALL_RPC_RESULT) do(e: Args):
      let params = connector_service.ConnectorCallRPCResultArgs(e)
      controller.emitConnectorCallRPCResult(params.requestId, params.payload)

    result.events.on(SIGNAL_CONNECTOR_DAPP_CHAIN_ID_SWITCHED) do(e: Args):
      try:
        let params = ConnectorDAppChainIdSwitchedSignal(e)
        let chainInfo = %*{
          "url": params.url,
          "chainId": params.chainId,
          "clientId": params.clientId
        }
        controller.emitChainIdSwitched(chainInfo.toJson())
      except Exception as ex:
        error "error processing SIGNAL_CONNECTOR_DAPP_CHAIN_ID_SWITCHED", error=ex.msg, exceptionName=ex.name

    result.events.on(SIGNAL_CONNECTOR_ACCOUNT_CHANGED) do(e: Args):
      try:
        let params = ConnectorAccountChangedSignal(e)
        let accountInfo = %*{
          "url": params.url,
          "clientId": params.clientId,
          "sharedAccount": params.sharedAccount
        }
        controller.emitAccountChanged(accountInfo.toJson())
      except Exception as ex:
        error "error processing SIGNAL_CONNECTOR_ACCOUNT_CHANGED", error=ex.msg, exceptionName=ex.name

    result.events.on(connector_service.SIGNAL_WC_SESSION_PROPOSAL) do(e: Args):
      try:
        let params = WCSessionProposalSignal(e)
        controller.wcSessionProposal(params.requestId, params.uri, params.proposal)
      except Exception as ex:
        error "error processing SIGNAL_WC_SESSION_PROPOSAL", error=ex.msg, exceptionName=ex.name

    result.events.on(connector_service.SIGNAL_WC_SESSION_REQUEST) do(e: Args):
      try:
        let params = WCSessionRequestSignal(e)
        controller.wcSessionRequest(params.topic, $params.requestId, params.requestJson)
      except Exception as ex:
        error "error processing SIGNAL_WC_SESSION_REQUEST", error=ex.msg, exceptionName=ex.name

    result.events.on(connector_service.SIGNAL_WC_SESSION_DELETE) do(e: Args):
      try:
        let params = WCSessionDeleteSignal(e)
        controller.wcSessionDelete(params.topic, params.dappUrl)
      except Exception as ex:
        error "error processing SIGNAL_WC_SESSION_DELETE", error=ex.msg, exceptionName=ex.name

    result.QObject.setup

  proc connectRequested*(self: Controller, requestId: string, payload: string) {.signal.}
  proc connected*(self: Controller, payload: string) {.signal.}
  proc disconnected*(self: Controller, payload: string) {.signal.}

  proc sendTransaction*(self: Controller, requestId: string, payload: string) {.signal.}
  proc sign(self: Controller, requestId: string, payload: string) {.signal.}
  proc approveConnectResponse*(self: Controller, payload: string, error: bool) {.signal.}
  proc rejectConnectResponse*(self: Controller, payload: string, error: bool) {.signal.}
  proc connectorCallRPCResult*(self: Controller, requestId: int, payload: string) {.signal.}
  proc chainIdSwitched*(self: Controller, payload: string) {.signal.}
  proc accountChanged*(self: Controller, payload: string) {.signal.}

  proc approveTransactionResponse*(self: Controller, topic: string, requestId: string, error: bool) {.signal.}
  proc rejectTransactionResponse*(self: Controller, topic: string, requestId: string, error: bool) {.signal.}
  proc approveSignResponse*(self: Controller, topic: string, requestId: string, error: bool) {.signal.}
  proc rejectSignResponse*(self: Controller, topic: string, requestId: string, error: bool) {.signal.}
  proc wcSessionProposal*(self: Controller, requestId: string, uri: string, proposal: string) {.signal.}
  proc wcSessionRequest*(self: Controller, topic: string, requestId: string, requestJson: string) {.signal.}
  proc wcSessionDelete*(self: Controller, topic: string, dappUrl: string) {.signal.}

  proc emitConnectRequested*(self: Controller, requestId: string, payload: string) =
    self.connectRequested(requestId, payload)

  proc emitConnected*(self: Controller, payload: string) =
    self.connected(payload)

  proc emitDisconnected*(self: Controller, payload: string) =
    self.disconnected(payload)

  proc emitSendTransaction*(self: Controller, requestId: string, payload: string) =
    self.sendTransaction(requestId, payload)

  proc emitSign*(self: Controller, requestId: string, payload: string) =
    self.sign(requestId, payload)

  proc emitConnectorCallRPCResult*(self: Controller, requestId: int, payload: string) =
    self.connectorCallRPCResult(requestId, payload)

  proc emitChainIdSwitched*(self: Controller, payload: string) =
    self.chainIdSwitched(payload)

  proc emitAccountChanged*(self: Controller, payload: string) =
    self.accountChanged(payload)

  proc parseSingleUInt(chainIDsString: string): uint =
    try:
      let chainIds = parseJson(chainIDsString)
      if chainIds.kind == JArray and chainIds.len > 0 and chainIds[0].kind == JInt:
        return uint(chainIds[0].getInt())
      else:
        raise newException(ValueError, "Invalid JSON array format")
    except JsonParsingError:
      raise newException(ValueError, "Failed to parse JSON")

  proc approveConnection*(self: Controller, requestId: string, account: string, chainIDString: string): bool {.slot.} =
    try:
      let chainId = parseSingleUInt(chainIDString)
      result = self.service.approveDappConnect(requestId, account, chainId)
      self.approveConnectResponse(requestId, not result)
    except ValueError:
      echo "Failed to parse chain ID"
      self.approveConnectResponse(requestId, true)


  proc rejectConnection*(self: Controller, requestId: string): bool {.slot.} =
    result = self.service.rejectDappConnect(requestId)
    self.rejectConnectResponse(requestId, not result)

  proc approveTransaction*(self: Controller, sessionTopic: string, requestId: string, signature: string): bool {.slot.} =
    result = self.service.approveTransactionRequest(requestId, signature)
    self.approveTransactionResponse(sessionTopic, requestId, not result)

  proc rejectTransaction*(self: Controller, sessionTopic: string, requestId: string): bool {.slot.} =
    result = self.service.rejectTransactionSigning(requestId)
    self.rejectTransactionResponse(sessionTopic, requestId, not result)

  proc disconnect*(self: Controller, dAppUrl: string, clientId: string = ""): bool {.slot.} =
    result = self.service.recallDAppPermission(dAppUrl, clientId)

  # WalletConnect (via connector)
  proc pairWalletConnect*(self: Controller, uri: string): bool {.slot.} =
    return self.service.pairWalletConnect(uri)

  proc approveWCSession*(self: Controller, proposalId: string, accountAddr: string, dappUrl: string, dappName: string, dappIcon: string, supportedChainsJson: string): string {.slot.} =
    let chains = Json.decode(supportedChainsJson, seq[uint64])
    return self.service.approveWCSession(proposalId, accountAddr, dappUrl, dappName, dappIcon, chains)

  proc rejectWCSession*(self: Controller, proposalId: string): bool {.slot.} =
    return self.service.rejectWCSession(proposalId)

  proc approveWCSessionRequest*(self: Controller, topic: string, requestId: string, signature: string): bool {.slot.} =
    return self.service.approveWCSessionRequest(topic, requestId, signature)

  proc rejectWCSessionRequest*(self: Controller, topic: string, requestId: string): bool {.slot.} =
    return self.service.rejectWCSessionRequest(topic, requestId)

  proc disconnectWCSession*(self: Controller, topic: string): bool {.slot.} =
    return self.service.disconnectWCSession(topic)

  proc getWCActiveSessions*(self: Controller, validAtTimestamp: int): string {.slot.} =
    return self.service.getWCActiveSessions(int64(validAtTimestamp))

  proc emitWCSessionEvent*(self: Controller, topic: string, name: string, dataJson: string, chainId: string): bool {.slot.} =
    return self.service.emitWCSessionEvent(topic, name, dataJson, chainId)

  proc getDApps*(self: Controller): string {.slot.} =
    return self.service.getDApps()

  proc getDAppsByClientId*(self: Controller, clientId: string): string {.slot.} =
    return self.service.getDAppsByClientId(clientId)

  proc approveSigning*(self: Controller, sessionTopic: string, requestId: string, signature: string): bool {.slot.} =
    result = self.service.approveSignRequest(requestId, signature)
    self.approveSignResponse(sessionTopic, requestId, not result)


  proc rejectSigning*(self: Controller, sessionTopic: string, requestId: string): bool {.slot.} =
    result = self.service.rejectSigning(requestId)
    self.rejectSignResponse(sessionTopic, requestId, not result)

  proc delete*(self: Controller) =
    self.QObject.delete

  proc connectorCallRPC*(self: Controller, requestId: int, message: string) {.slot.} =
    self.service.connectorCallRPC(requestId, message)

  proc changeAccount*(self: Controller, url: string, clientId: string, newAccount: string): bool {.slot.} =
    result = self.service.changeAccount(url, clientId, newAccount)
