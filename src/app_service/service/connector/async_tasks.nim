import json, json_serialization, chronicles
import base64 as base64lib
import backend/connector as status_go
import app/core/tasks/qt

logScope:
  topics = "connector-async-tasks"

type
  ConnectorCallRPCTaskArg* = ref object of QObjectTaskArg
    requestId*: int
    messageBase64*: string  # Base64 encoded message to avoid JSON escaping issues

proc connectorCallRPCTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[ConnectorCallRPCTaskArg](argEncoded)
  
  # Decode message from base64
  let message = try:
    base64lib.decode(arg.messageBase64)
  except:
    error "Failed to decode base64 message", requestId=arg.requestId
    arg.finish(%* {
      "requestId": arg.requestId,
      "error": "Failed to decode message"
    })
    return
  
  try:
    let rpcResponse = status_go.connectorCallRPC(message)
    let responseJson = %* {
      "requestId": arg.requestId,
      "result": rpcResponse.result,
      "error": if rpcResponse.error.isNil: "" else: rpcResponse.error.message
    }
    
    arg.finish(responseJson)
  except Exception as e:
    error "connectorCallRPCTask failed", errorMsg=e.msg
    arg.finish(%* {
      "requestId": arg.requestId,
      "error": e.msg
    })

