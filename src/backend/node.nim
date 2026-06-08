import core

proc getRpcStats*(): string =
    result = callPrivateRPCNoDecode("rpcstats_getStats")

proc resetRpcStats*() =
    discard callPrivateRPCNoDecode("rpcstats_reset")
