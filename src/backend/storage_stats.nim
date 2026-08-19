## Thin wrapper around the status-go `storagestats` JSON-RPC namespace.
## See vendor/status-go/services/storagestats/service.go for the server side.
import json
import core
import response_type

export response_type

proc prefix*(methodName: string): string =
  result = "storagestats_" & methodName

## Returns the request id carried by the resulting `storage-stats.progress` /
## `storage-stats.result` signals. Returns immediately; status-go does the walk
## on its own goroutine.
proc collect*(): RpcResponse[JsonNode] {.raises: [RpcException].} =
  callPrivateRPC("collect".prefix)
