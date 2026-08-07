import json, json_serialization, chronicles
import response_type

import status_go

export response_type

logScope:
  topics = "rpc-privacy"

proc changeDatabasePassword*(keyUID: string, oldHashedPassword: string, newHashedPassword: string,
  rekey: bool = false): RpcResponse[JsonNode]
  =
  try:
    let request = %* {
      "keyUID": keyUID,
      "oldPassword": oldHashedPassword,
      "newPassword": newHashedPassword,
      "rekey": rekey,
    }
    let response = status_go.changeDatabasePasswordV2($request)
    result.result = Json.decode(response, JsonNode)
  except RpcException as e:
    error "error", methodName = "changeDatabasePassword", exception=e.msg
    raise newException(RpcException, e.msg)

proc getProfileEncryptionInfo*(keyUID: string): RpcResponse[JsonNode] =
  try:
    let request = %* {
      "keyUID": keyUID,
    }
    let response = status_go.getProfileEncryptionInfo($request)
    result.result = Json.decode(response, JsonNode)
  except RpcException as e:
    error "error", methodName = "getProfileEncryptionInfo", exception=e.msg
    raise newException(RpcException, e.msg)
