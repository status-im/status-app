import json, strutils, json_serialization, chronicles
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

proc logout*(): RpcResponse[JsonNode] =
  try:
    let response = status_go.logout()
    result.result = Json.decode(response, JsonNode)
  except RpcException as e:
    error "error logging out", methodName = "logout", exception=e.msg
    raise newException(RpcException, e.msg)

proc adminPeers*(): RpcResponse[JsonNode] =
  let payload = %* []
  result = core.callPrivateRPC("admin_peers", payload)

proc wakuV2Peers*(): RpcResponse[JsonNode] =
  let payload = %* []
  result = core.callPrivateRPC("peers".prefix, payload)

proc getPasswordStrengthScore*(password: string, userInputs: seq[string]): RpcResponse[JsonNode] =
  let params = %* {"password": password, "userInputs": userInputs}
  try:
    let response = status_go.getPasswordStrengthScore($(params))
    result.result = Json.decode(response, JsonNode)
  except RpcException as e:
    error "error", methodName = "getPasswordStrengthScore", exception=e.msg
    raise newException(RpcException, e.msg)

proc importLocalBackupFile*(filePath: string): RpcResponse[JsonNode] =
  let payload = %* [filePath]
  result = callPrivateRPC("importLocalBackupFile".prefix, payload)

proc hashMessageForSigning*(message: string): string =
  try:
    let response = status_go.hashMessage(message)
    let jsonResponse = parseJson(response)
    return jsonResponse{"result"}.getStr()
  except Exception as e:
    error "hashMessage: failed to parse json response", error = e.msg
    return ""
