import core, chronicles, json
import ../app_service/common/utils

logScope:
    topics = "rpc-node"

proc getRpcStats*(): string =
    result = callPrivateRPCNoDecode("rpcstats_getStats")

proc resetRpcStats*() =
    discard callPrivateRPCNoDecode("rpcstats_reset")

## endpoints is "none", "all", "source" or "host"; key names the source or host.
proc getHttpTrafficReport*(endpoints: string, key: string): string =
    result = callPrivateRPCNoDecode("wallet_getHTTPTrafficReport", %*[{"endpoints": endpoints, "key": key}])

proc resetHttpTrafficStats*() =
    discard callPrivateRPCNoDecode("wallet_resetHTTPTrafficStats")

proc setHttpTrafficStatsEnabled*(enabled: bool) =
    discard callPrivateRPCNoDecode("wallet_setHTTPTrafficStatsEnabled", %*[enabled])

proc getConnectionStatus*(): bool =
    try:
        let response = callPrivateRPC("connectionStatus".prefix, %*[])
        let isOnline = response.result{"isOnline"}
        if isOnline.kind != JNull:
            return isOnline.getBool()
    except Exception as e:
        error "error:", methodName="getConnectionStatus", errName=e.name, errDesription=e.msg

    return false
