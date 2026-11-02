import json, strutils, json_serialization, chronicles, results
import core, ../app_service/common/utils
import response_type

import status_go

export response_type

logScope:
  topics = "rpc-general"

proc getRandomMnemonic*(): RpcResponse[JsonNode] =
  let response = status_go.getRandomMnemonic() # returns raw mnemonic string
  try:
    let parsed = parseJson(response)
    if parsed.kind == JObject and parsed.hasKey("error"):
      let errMsg = parsed["error"].getStr
      result.error = RpcError(code: -1, message: errMsg)
      error "error: ", procName="getRandomMnemonic", errDesription = errMsg
      return result
  except Exception as e:
    info "random mnemonic generated successfully"
  result.result = %* response # mnemonic is here, so return it as is

proc validateMnemonic*(mnemonic: string): RpcResponse[JsonNode] =
  try:
    let response = status_go.validateMnemonic(mnemonic.strip())
    result.result = Json.decode(response, JsonNode)

  except RpcException as e:
    error "error doing rpc request", methodName = "validateMnemonic", exception=e.msg
    raise newException(RpcException, e.msg)

proc startMessenger*(): RpcResponse[JsonNode] =
  let payload = %* []
  result = core.callPrivateRPC("startMessenger".prefix, payload)

type LogoutResponse* = object
  signalEpoch*: uint64 ## 0 when the response carries none
  error*: string

proc parseLogoutResponse*(response: string): LogoutResponse =
  ## status-go may have started the next signal epoch even when Logout failed later
  ## on, so the epoch is read whatever the outcome.
  try:
    let json = parseJson(response)
    result.error = json{"error"}.getStr
    result.signalEpoch = uint64(max(json{"signalEpoch"}.getBiggestInt, 0))
  except CatchableError as e:
    result.error = e.msg
  if result.error.len == 0 and result.signalEpoch == 0:
    result.error = "no signal epoch in the logout response"

proc logout*(): LogoutResponse =
  parseLogoutResponse(status_go.logout())

proc readSignalEpoch*(): Result[uint64, string] =
  ## The epoch the backend stamps on the signals it sends from now on.
  try:
    let epoch = parseJson(status_go.signalEpoch()){"signalEpoch"}.getBiggestInt
    if epoch <= 0:
      return err("no signal epoch in the response")
    ok(uint64(epoch))
  except CatchableError as e:
    err(e.msg)

proc wakuPeerCount*(): RpcResponse[JsonNode] =
  return core.callPrivateRPC("peers".prefix)

proc getPasswordStrengthScore*(password: string, userInputs: seq[string]): RpcResponse[JsonNode] =
  let params = %* {"password": password, "userInputs": userInputs}
  try:
    let response = status_go.getPasswordStrengthScore($(params))
    result.result = Json.decode(response, JsonNode)
  except RpcException as e:
    error "error", methodName = "getPasswordStrengthScore", exception=e.msg
    raise newException(RpcException, e.msg)

proc importLocalBackupFile*(filePath: string): RpcResponse[JsonNode] =
  let request = %* {"filePath": filePath}
  let response = status_go.loadLocalBackup($(request))
  return Json.decode(response, RpcResponse[JsonNode])

proc hashMessageForSigning*(message: string): string =
  try:
    let response = status_go.hashMessage(message)
    let jsonResponse = parseJson(response)
    return jsonResponse{"result"}.getStr()
  except Exception as e:
    error "hashMessage: failed to parse json response", error = e.msg
    return ""
