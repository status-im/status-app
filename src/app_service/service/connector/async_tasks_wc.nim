import json, json_serialization
import chronicles
import backend/connector as status_go

const
  WC_REJECT_SESSION_REQUEST_CODE = 5000
  WC_REJECT_SESSION_REQUEST_MESSAGE = "User rejected"

type
  PairWalletConnectTaskArg* = ref object of QObjectTaskArg
    requestId*: string
    uri*: string
  ApproveWCSessionTaskArg* = ref object of QObjectTaskArg
    requestId*: string
    proposalId*: string
    account*: string
    dappUrl*: string
    dappName*: string
    dappIcon*: string
    supportedChainsJson*: string
  RejectWCSessionTaskArg* = ref object of QObjectTaskArg
    requestId*: string
    proposalId*: string
  ApproveWCSessionRequestTaskArg* = ref object of QObjectTaskArg
    requestId*: string
    topic*: string
    sessionRequestId*: string
    signature*: string
  RejectWCSessionRequestTaskArg* = ref object of QObjectTaskArg
    requestId*: string
    topic*: string
    sessionRequestId*: string
  EmitWCSessionEventTaskArg* = ref object of QObjectTaskArg
    requestId*: string
    topic*: string
    name*: string
    dataJson*: string
    chainId*: string
  GetWCActiveSessionsTaskArg* = ref object of QObjectTaskArg
    requestId*: string
    validAtTimestamp*: int64
  DisconnectWCSessionTaskArg* = ref object of QObjectTaskArg
    requestId*: string
    topic*: string

proc pairWalletConnectTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[PairWalletConnectTaskArg](argEncoded)
  try:
    let rpcResponse = status_go.pairWalletConnectRpc(arg.uri)
    arg.finish(%* {
      "requestId": arg.requestId,
      "ok": rpcResponse.error.isNil,
      "error": if rpcResponse.error.isNil: "" else: rpcResponse.error.message
    })
  except Exception as e:
    error "pairWalletConnectTask failed", error=e.msg
    arg.finish(%* {"requestId": arg.requestId, "ok": false, "error": e.msg})

proc approveWCSessionTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[ApproveWCSessionTaskArg](argEncoded)
  try:
    let supportedChains = Json.decode(arg.supportedChainsJson, seq[uint64])
    let rpcResponse = status_go.approveWCSessionRpc(
      arg.proposalId,
      arg.account,
      arg.dappUrl,
      arg.dappName,
      arg.dappIcon,
      supportedChains
    )
    arg.finish(%* {
      "requestId": arg.requestId,
      "proposalId": arg.proposalId,
      "sessionJson": if rpcResponse.error.isNil: rpcResponse.result.getStr("") else: "",
      "ok": rpcResponse.error.isNil,
      "error": if rpcResponse.error.isNil: "" else: rpcResponse.error.message
    })
  except Exception as e:
    error "approveWCSessionTask failed", error=e.msg
    arg.finish(%* {
      "requestId": arg.requestId,
      "proposalId": arg.proposalId,
      "sessionJson": "",
      "ok": false,
      "error": e.msg
    })

proc rejectWCSessionTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[RejectWCSessionTaskArg](argEncoded)
  try:
    let ok = status_go.rejectWCSessionRpc(arg.proposalId)
    arg.finish(%* {
      "requestId": arg.requestId,
      "proposalId": arg.proposalId,
      "ok": ok,
      "error": if ok: "" else: "Failed to reject session"
    })
  except Exception as e:
    error "rejectWCSessionTask failed", error=e.msg
    arg.finish(%* {"requestId": arg.requestId, "proposalId": arg.proposalId, "ok": false, "error": e.msg})

proc approveWCSessionRequestTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[ApproveWCSessionRequestTaskArg](argEncoded)
  try:
    let ok = status_go.approveWCSessionRequestRpc(arg.topic, arg.sessionRequestId, arg.signature)
    arg.finish(%* {
      "requestId": arg.requestId,
      "topic": arg.topic,
      "sessionRequestId": arg.sessionRequestId,
      "accept": true,
      "ok": ok,
      "error": if ok: "" else: "Failed to send signature"
    })
  except Exception as e:
    error "approveWCSessionRequestTask failed", error=e.msg
    arg.finish(%* {
      "requestId": arg.requestId,
      "topic": arg.topic,
      "sessionRequestId": arg.sessionRequestId,
      "accept": true,
      "ok": false,
      "error": e.msg
    })

proc rejectWCSessionRequestTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[RejectWCSessionRequestTaskArg](argEncoded)
  try:
    let ok = status_go.rejectWCSessionRequestRpc(
      arg.topic,
      arg.sessionRequestId,
      WC_REJECT_SESSION_REQUEST_CODE,
      WC_REJECT_SESSION_REQUEST_MESSAGE
    )
    arg.finish(%* {
      "requestId": arg.requestId,
      "topic": arg.topic,
      "sessionRequestId": arg.sessionRequestId,
      "accept": false,
      "ok": ok,
      "error": if ok: "" else: "Failed to reject"
    })
  except Exception as e:
    error "rejectWCSessionRequestTask failed", error=e.msg
    arg.finish(%* {
      "requestId": arg.requestId,
      "topic": arg.topic,
      "sessionRequestId": arg.sessionRequestId,
      "accept": false,
      "ok": false,
      "error": e.msg
    })

proc emitWCSessionEventTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[EmitWCSessionEventTaskArg](argEncoded)
  try:
    let ok = status_go.emitWCSessionEventRpc(arg.topic, arg.name, arg.dataJson, arg.chainId)
    arg.finish(%* {
      "requestId": arg.requestId,
      "topic": arg.topic,
      "name": arg.name,
      "ok": ok,
      "error": if ok: "" else: "Failed to emit session event"
    })
  except Exception as e:
    error "emitWCSessionEventTask failed", error=e.msg
    arg.finish(%* {
      "requestId": arg.requestId,
      "topic": arg.topic,
      "name": arg.name,
      "ok": false,
      "error": e.msg
    })

proc getWCActiveSessionsTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[GetWCActiveSessionsTaskArg](argEncoded)
  try:
    let rpcResponse = status_go.getWCActiveSessionsRpc(arg.validAtTimestamp)
    let sessionsJson = if rpcResponse.error.isNil:
      let jsonArray = $rpcResponse.result
      if jsonArray != "null": jsonArray else: "[]"
    else:
      "[]"
    arg.finish(%* {
      "requestId": arg.requestId,
      "validAtTimestamp": arg.validAtTimestamp,
      "sessionsJson": sessionsJson,
      "ok": rpcResponse.error.isNil,
      "error": if rpcResponse.error.isNil: "" else: rpcResponse.error.message
    })
  except Exception as e:
    error "getWCActiveSessionsTask failed", error=e.msg
    arg.finish(%* {
      "requestId": arg.requestId,
      "validAtTimestamp": arg.validAtTimestamp,
      "sessionsJson": "[]",
      "ok": false,
      "error": e.msg
    })

proc disconnectWCSessionTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[DisconnectWCSessionTaskArg](argEncoded)
  try:
    let ok = status_go.disconnectWCSessionRpc(arg.topic)
    arg.finish(%* {
      "requestId": arg.requestId,
      "topic": arg.topic,
      "ok": ok,
      "error": if ok: "" else: "Failed to disconnect session"
    })
  except Exception as e:
    error "disconnectWCSessionTask failed", error=e.msg
    arg.finish(%* {"requestId": arg.requestId, "topic": arg.topic, "ok": false, "error": e.msg})
