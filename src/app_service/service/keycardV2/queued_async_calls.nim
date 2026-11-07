proc onAsyncResponse(self: Service, response: string) {.slot.} =
  try:
    let responseObj = response.parseJson
    let requestId = responseObj["requestId"].getInt()
    if not self.requestMap.hasKey(requestId):
      raise newException(Exception, "unexpected request id")
    defer:
      self.requestMap.del(requestId) #it's safe to delete here, cause if the key does not exist it does nothing
    if responseObj{"error"}.kind != JNull and responseObj{"error"}.getStr != "":
      self.requestMap[requestId].callback(newJNull(), responseObj{"error"}.getStr)
      return
    let rpcResponseObj = responseObj["response"].getStr().parseJson()
    self.requestMap[requestId].callback(rpcResponseObj, "")
  except Exception as e:
    error "onAsyncResponse", err=e.msg

proc asyncCallRPC(self: Service, action: KeycardAction, params: JsonNode, callback: proc (responseObj: JsonNode, err: string)) =
  # callRPC answers Stop/Cancel itself while nothing is loaded
  if action notin {KeycardAction.Stop, KeycardAction.CancelCurrentOperation}:
    loadLib()
  self.requestCounter.inc
  self.requestMap[self.requestCounter] = KeycardRequest(
    action: action,
    params: params,
    callback: callback
  )
  let arg = AsyncRequestArg(
    tptr: asyncRequestTask,
    vptr: cast[uint](self.vptr),
    slot: "onAsyncResponse",
    requestId: self.requestCounter,
    action: $action,
    params: params,
  )
  self.threadpool.start(arg)