import json
import ./core, ./response_type

export response_type

proc suggestedFees*(chainId: int): RpcResponse[JsonNode] =
  let payload = %* [chainId]
  return core.callPrivateRPC("wallet_getSuggestedFees", payload)
