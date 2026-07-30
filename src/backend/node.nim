import core, chronicles, json
import ../app_service/common/utils

logScope:
    topics = "rpc-node"

proc getRpcStats*(): string =
    result = callPrivateRPCNoDecode("rpcstats_getStats")

proc resetRpcStats*() =
    discard callPrivateRPCNoDecode("rpcstats_reset")

proc getConnectionStatus*(): bool =
    try:
        let response = callPrivateRPC("connectionStatus".prefix, %*[])
        let isOnline = response.result{"isOnline"}
        if isOnline.kind != JNull:
            return isOnline.getBool()
    except Exception as e:
        error "error:", methodName="getConnectionStatus", errName=e.name, errDesription=e.msg

    return false
