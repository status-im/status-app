proc initializeRPC(self: Service) {.slot, featureGuard(KEYCARD_ENABLED).} =
  try:
    var response = keycard_go.keycardInitializeRPC()
  except Exception as e:
    error "error initializing keycard", err=e.msg

proc asyncStart(self: Service, storageDir: string) {.featureGuard(KEYCARD_ENABLED).} =
  let params = %*{
    "storageFilePath": storageDir,
    "logEnabled": KEYCARD_LOGS_ENABLED,
    "logFilePath": KEYCARD_LOG_FILE_PATH,
  }
  self.asyncCallRPC(KeycardAction.Start, params, proc (responseObj: JsonNode, err: string) {.featureGuard(KEYCARD_ENABLED).} =
    if err.len > 0:
      error "error starting keycard", err=err
      return
    debug "keycard started"
  )

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

proc generateMnemonic*(self: Service, length: int): string {.featureGuard(KEYCARD_ENABLED).} =
  try:
    let response = callRPC($KeycardAction.GenerateMnemonic, %*{"length": length})
    let rpcResponseObj = response.parseJson
    if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
        let error = Json.decode(rpcResponseObj["error"].getStr, RpcError)
        raise newException(RpcException, error.message)

    let indexes = rpcResponseObj["result"]["indexes"]
    let words = buildSeedPhrasesFromIndexes(indexes)
    let mnemonic = words.join(" ")
    return mnemonic
  except Exception as e:
    error "error generating mnemonic", err=e.msg

proc getMetadata*(self: Service): CardMetadataDto {.featureGuard(KEYCARD_ENABLED).} =
  try:
    let response = callRPC($KeycardAction.GetMetadata)
    let rpcResponseObj = response.parseJson
    if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
      let error = Json.decode(rpcResponseObj["error"].getStr, RpcError)
      raise newException(RpcException, error.message)
    return rpcResponseObj["result"].toCardMetadataDto()
  except Exception as e:
    error "error getting metadata", err=e.msg

proc asyncLoadMnemonic*(self: Service, mnemonic: string) {.featureGuard(KEYCARD_ENABLED).} =
  let params = %*{"mnemonic": mnemonic}
  self.asyncCallRPC(KeycardAction.LoadMnemonic, params, proc (responseObj: JsonNode, err: string) =
    if err.len > 0:
      error "error loading mnemonic", err=err
      self.events.emit(SIGNAL_KEYCARD_LOAD_MNEMONIC_FAILURE, KeycardErrorArg(error: err))
      return
    let keyUID = responseObj["result"]["keyUID"].getStr
    self.events.emit(SIGNAL_KEYCARD_LOAD_MNEMONIC_SUCCESS, KeycardKeyUIDArg(keyUID: keyUID))
  )

proc asyncAuthorize*(self: Service, pin: string) {.featureGuard(KEYCARD_ENABLED).} =
  let params = %*{"pin": pin}
  self.asyncCallRPC(KeycardAction.Authorize, params, proc (responseObj: JsonNode, err: string) =
    if err.len > 0:
      error "error authorizing", err=err
      let event = KeycardAuthorizeEvent(error: err, authorized: false)
      self.events.emit(SIGNAL_KEYCARD_AUTHORIZE_FINISHED, event)
      return

    if responseObj.hasKey("error") and responseObj["error"].kind != JNull:
      let rpcErrorObj = responseObj["error"]
      let rpcError = if rpcErrorObj.kind == JString: rpcErrorObj.getStr() else: $rpcErrorObj
      if rpcError.len > 0:
        error "error authorizing", err=rpcError
        let event = KeycardAuthorizeEvent(error: rpcError, authorized: false)
        self.events.emit(SIGNAL_KEYCARD_AUTHORIZE_FINISHED, event)
        return

    let resultObj = responseObj{"result"}
    if resultObj.kind == JNull or resultObj{"authorized"}.kind == JNull:
      let reason = "missing authorize result"
      error "error authorizing", err=reason
      let event = KeycardAuthorizeEvent(error: reason, authorized: false)
      self.events.emit(SIGNAL_KEYCARD_AUTHORIZE_FINISHED, event)
      return

    let event = KeycardAuthorizeEvent(
      error: "",
      authorized: resultObj{"authorized"}.getBool(),
    )
    self.events.emit(SIGNAL_KEYCARD_AUTHORIZE_FINISHED, event)
  )

proc asyncInitialize*(self: Service, pin: string, puk: string) {.featureGuard(KEYCARD_ENABLED).} =
  let params = %*{
    "pin": pin,
    "puk": puk,
    "pairingPassword": "", # we keep it empty for now
  }
  self.asyncCallRPC(KeycardAction.Initialize, params, proc (responseObj: JsonNode, err: string) =
    if err.len > 0:
      error "error initializing keycard", err=err
      self.events.emit(SIGNAL_KEYCARD_SET_PIN_FAILURE, KeycardErrorArg(error: err))
      return
    debug "keycard initialized"
  )

proc asyncExportRecoverKeys*(self: Service) {.featureGuard(KEYCARD_ENABLED).} =
  let params = %*{}
  self.asyncCallRPC(KeycardAction.ExportRecoverKeys, params, proc (responseObj: JsonNode, err: string) =
    if err.len > 0:
      error "error exporting recover keys", err=err
      self.events.emit(SIGNAL_KEYCARD_EXPORT_RESTORE_KEYS_FAILURE, KeycardErrorArg(error: err))
      return
    let keys = responseObj["result"]["keys"].toKeycardExportedKeysDto()
    self.events.emit(SIGNAL_KEYCARD_EXPORT_RESTORE_KEYS_SUCCESS, KeycardExportedKeysArg(exportedKeys: keys))
  )

proc asyncExportLoginKeys*(self: Service) {.featureGuard(KEYCARD_ENABLED).} =
  let params = %*{}
  self.asyncCallRPC(KeycardAction.ExportLoginKeys, params, proc (responseObj: JsonNode, err: string) =
    if err.len > 0:
      error "error exporting login keys", err=err
      self.events.emit(SIGNAL_KEYCARD_EXPORT_LOGIN_KEYS_FAILURE, KeycardErrorArg(error: err))
      return
    let keys = responseObj["result"]["keys"].toKeycardExportedKeysDto()
    self.events.emit(SIGNAL_KEYCARD_EXPORT_LOGIN_KEYS_SUCCESS, KeycardExportedKeysArg(exportedKeys: keys))
  )

proc asyncFactoryReset*(self: Service) {.featureGuard(KEYCARD_ENABLED).} =
  let params = %*{}
  self.asyncCallRPC(KeycardAction.FactoryReset, params, proc (responseObj: JsonNode, err: string) =
    if err.len > 0:
      error "error factory reset", err=err
      return
    debug "factory reset"
  )

proc asyncStoreMetadata*(self: Service, name: string, paths: seq[string]) {.featureGuard(KEYCARD_ENABLED).} =
  let params = %*{"name": name, "paths": paths}
  self.asyncCallRPC(KeycardAction.StoreMetadata, params, proc (responseObj: JsonNode, err: string) =
    if err.len > 0:
      error "error storing metadata", err=err
      return
    debug "metadata stored"
  )

proc storeMetadata*(self: Service, name: string, paths: seq[string]) {.featureGuard(KEYCARD_ENABLED).} =
  try:
    let response = callRPC($KeycardAction.StoreMetadata, %*{"name": name, "paths": paths})
    let rpcResponseObj = response.parseJson
    if rpcResponseObj{"error"}.kind != JNull and rpcResponseObj{"error"}.getStr != "":
        let error = Json.decode(rpcResponseObj["error"].getStr, RpcError)
        raise newException(RpcException, error.message)
  except Exception as e:
    error "error storing metadata", err=e.msg

# TODO: remove this function
proc startDetection*(self: Service) {.featureGuard(KEYCARD_ENABLED).} =
  self.asyncStart(status_const.KEYCARDPAIRINGDATAFILE)

# TODO: remove this function
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
