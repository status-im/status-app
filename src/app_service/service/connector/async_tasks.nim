import json, json_serialization, chronicles
import backend/connector as status_go
import app/core/tasks/qt

logScope:
  topics = "connector-async-tasks"

type
  ConnectorCallRPCTaskArg* = ref object of QObjectTaskArg
    requestId*: int
    message*: JsonNode

proc connectorCallRPCTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[ConnectorCallRPCTaskArg](argEncoded)
  try:
    let rpcResponse = status_go.connectorCallRPC($arg.message)
    let responseJson = %* {
      "requestId": arg.requestId,
      "result": rpcResponse.result,
      "error": if rpcResponse.error.isNil: "" else: rpcResponse.error.message
    }
    
    arg.finish(responseJson)
  except Exception as e:
    error "connectorCallRPCTask failed", error=e.msg
    arg.finish(%* {
      "requestId": arg.requestId,
      "error": e.msg
    })

