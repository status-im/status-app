## Thin wrappers around the status-go `preferences` JSON-RPC namespace.
## Server side: pkg/services/preferences/api.go in status-go.
import json
import core
import response_type

export response_type

proc prefix*(methodName: string): string =
  result = "preferences_" & methodName

proc get*(category, key: string): RpcResponse[JsonNode] {.raises: [RpcException].} =
  callPrivateRPC("get".prefix, %*[category, key])

proc set*(category, key, value: string): RpcResponse[JsonNode] {.raises: [RpcException].} =
  callPrivateRPC("set".prefix, %*[category, key, value])

proc deleteCategory*(category: string): RpcResponse[JsonNode] {.raises: [RpcException].} =
  callPrivateRPC("deleteCategory".prefix, %*[category])

proc purgeUnknown*(category: string, validKeys: seq[string]): RpcResponse[JsonNode] {.raises: [RpcException].} =
  callPrivateRPC("purgeUnknown".prefix, %*[category, validKeys])
