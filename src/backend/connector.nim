import options
import json, json_serialization
import core, response_type
import chronicles

from gen import rpc

logScope:
  topics = "connector-backend"

const
  EventConnectorSendRequestAccounts* = "connector.sendRequestAccounts"
  EventConnectorSendTransaction* = "connector.sendTransaction"

type RequestAccountsAcceptedArgs* = ref object of RootObj
  requestId* {.serializedFieldName("requestId").}: string
  account* {.serializedFieldName("account").}: string
  chainId* {.serializedFieldName("chainId").}: uint

type SendTransactionAcceptedArgs* = ref object of RootObj
  requestId* {.serializedFieldName("requestId").}: string
  hash* {.serializedFieldName("hash").}: string

type RejectedArgs* = ref object of RootObj
  requestId* {.serializedFieldName("requestId").}: string

type SignAcceptedArgs* = ref object of RootObj
  requestId* {.serializedFieldName("requestId").}: string
  signature* {.serializedFieldName("signature").}: string

type ChangeAccountArgs* = ref object of RootObj
  url* {.serializedFieldName("url").}: string
  account* {.serializedFieldName("account").}: string
  clientID* {.serializedFieldName("clientId").}: string

rpc(requestAccountsAccepted, "connector"):
  args: RequestAccountsAcceptedArgs

rpc(sendTransactionAccepted, "connector"):
  args: SendTransactionAcceptedArgs

rpc(sendTransactionRejected, "connector"):
  aargs: RejectedArgs

rpc(requestAccountsRejected, "connector"):
  args: RejectedArgs

rpc(recallDAppPermissionV2, "connector"):
  url: string
  clientId: string

rpc(getPermittedDAppsList, "connector"):
  discard

rpc(signAccepted, "connector"):
  args: SignAcceptedArgs

rpc(signRejected, "connector"):
  args: RejectedArgs

rpc(callRPC, "connector"):
  inputJSON: string

rpc(changeAccount, "connector"):
  args: ChangeAccountArgs

# WalletConnect (via connector)
rpc(pairWalletConnect, "connector"):
  uri: string

rpc(disconnectWCSession, "connector"):
  topic: string

rpc(getWCActiveSessions, "connector"):
  validAtTimestamp: int64

rpc(approveWCSession, "connector"):
  proposalId: string
  account: string
  chainId: uint64
  dappUrl: string
  dappName: string
  dappIcon: string

rpc(rejectWCSession, "connector"):
  proposalId: string

rpc(approveWCSessionRequest, "connector"):
  topic: string
  requestId: string
  signature: string

rpc(rejectWCSessionRequest, "connector"):
  topic: string
  requestId: string
  code: int
  message: string

proc isSuccessResponse(rpcResponse: RpcResponse[JsonNode]): bool =
  return rpcResponse.error.isNil

proc requestAccountsAcceptedFinishedRpc*(args: RequestAccountsAcceptedArgs): bool =
  return isSuccessResponse(requestAccountsAccepted(args))

proc requestAccountsRejectedFinishedRpc*(args: RejectedArgs): bool =
  return isSuccessResponse(requestAccountsRejected(args))

proc sendTransactionAcceptedFinishedRpc*(args: SendTransactionAcceptedArgs): bool =
  return isSuccessResponse(sendTransactionAccepted(args))

proc sendTransactionRejectedFinishedRpc*(args: RejectedArgs): bool =
  return isSuccessResponse(sendTransactionRejected(args))

proc recallDAppPermissionFinishedRpc*(dAppUrl: string, clientId: string): bool =
  return isSuccessResponse(recallDAppPermissionV2(dAppUrl, clientId))

proc sendSignAcceptedFinishedRpc*(args: SignAcceptedArgs): bool =
  return isSuccessResponse(signAccepted(args))

proc sendSignRejectedFinishedRpc*(args: RejectedArgs): bool =
  return isSuccessResponse(signRejected(args))

proc connectorCallRPC*(inputJSON: string): RpcResponse[JsonNode] {.raises: [Exception].} =
  return callRPC(inputJSON)

proc changeAccountFinishedRpc*(args: ChangeAccountArgs): bool =
  return isSuccessResponse(changeAccount(args))

proc pairWalletConnectRpc*(uri: string): RpcResponse[JsonNode] {.raises: [Exception].} =
  return pairWalletConnect(uri)

proc disconnectWCSessionRpc*(topic: string): bool =
  return isSuccessResponse(disconnectWCSession(topic))

proc getWCActiveSessionsRpc*(validAtTimestamp: int64): RpcResponse[JsonNode] {.raises: [Exception].} =
  return getWCActiveSessions(validAtTimestamp)

proc approveWCSessionRpc*(proposalId, account: string, chainId: uint64, dappUrl, dappName, dappIcon: string): RpcResponse[JsonNode] {.raises: [Exception].} =
  return approveWCSession(proposalId, account, chainId, dappUrl, dappName, dappIcon)

proc rejectWCSessionRpc*(proposalId: string): bool =
  return isSuccessResponse(rejectWCSession(proposalId))

proc approveWCSessionRequestRpc*(topic, requestId, signature: string): bool =
  return isSuccessResponse(approveWCSessionRequest(topic, requestId, signature))

proc rejectWCSessionRequestRpc*(topic, requestId: string, code: int, message: string): bool =
  return isSuccessResponse(rejectWCSessionRequest(topic, requestId, code, message))
