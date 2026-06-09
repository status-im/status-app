proc asyncStop*(self: Service)  {.featureGuard(KEYCARD_ENABLED).} =
  let params = %*{}
  self.asyncCallRPC(KeycardAction.Stop, params, proc (responseObj: JsonNode, err: string) =
    if err.len > 0:
      error "error stopping keycard", err=err
      return
    debug "keycard stopped"
  )

proc stop*(self: Service)  {.featureGuard(KEYCARD_ENABLED).} =
  try:
    let response = callRPC($KeycardAction.Stop)
    let rpcResponseObj = response.parseJson
    if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
        let error = Json.decode(rpcResponseObj["error"].getStr, RpcError)
        raise newException(RpcException, error.message)
  except Exception as e:
    error "error stop", err=e.msg

proc cancelCurrentOperation*(self: Service) {.featureGuard(KEYCARD_ENABLED).} =
  let params = %*{}
  self.asyncCallRPC(KeycardAction.CancelCurrentOperation, params, proc (responseObj: JsonNode, err: string) =
    if err.len > 0:
      error "error canceling current keycard operation", reason=err
      return
    if responseObj.hasKey("error") and responseObj["error"].kind != JNull:
      let errorObj = responseObj["error"]
      if errorObj.hasKey("message"):
        let reason = errorObj["message"].getStr()
        error "error canceling current keycard operation", reason=reason
      else:
        let reason = $errorObj
        error "error canceling current keycard operation", reason=reason
  )
