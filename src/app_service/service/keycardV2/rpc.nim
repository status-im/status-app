import json
import app/global/feature_flags

featureGuard KEYCARD_ENABLED:
  import keycard_lib

var rpcCounter: int = 0

proc loadLib*() {.featureGuard(KEYCARD_ENABLED).} =
  keycard_lib.ensureLoaded()

proc callRPC*(methodName: string, params: JsonNode = %*{}): string  {.featureGuard(KEYCARD_ENABLED).}=
    # Nothing to stop or cancel before a real call has loaded the library
    if methodName in ["Stop", "CancelCurrentOperation"] and not keycard_lib.isLoaded():
      return """{"result":null,"error":null}"""
    rpcCounter.inc
    let request = %*{
      "id": rpcCounter,
      "method": "keycard." & methodName,
      "params": %*[ params ],
    }
    let responseString = keycard_lib.keycardCallRPC($request)
    return responseString
