proc asyncLogin*(self: Service, keyUid: string, pin: string) {.featureGuard(KEYCARD_ENABLED).} =
  let params = %*{
    "storageFilePath": status_const.KEYCARDPAIRINGDATAFILE,
    "logEnabled": status_const.KEYCARD_LOGS_ENABLED,
    "logFilePath": status_const.KEYCARD_LOG_FILE_PATH,
    "keyUid": keyUid,
    "pin": pin,
  }
  self.asyncCallRPC(KeycardAction.Login, params, proc (responseObj: JsonNode, err: string) =
    var data = KeycardLoginArgs()
    try:
      if err.len > 0:
        raise newException(CatchableError, "login action parsing response error: " & err)
      if responseObj.hasKey("error") and responseObj["error"].kind != JNull:
        let errorObj = responseObj["error"]
        if errorObj.hasKey("message"):
          raise newException(CatchableError, "login action keycard response error: " & errorObj["message"].getStr())
        raise newException(CatchableError, "login action keycard response unknown error")
      # since this is a composite action, the login response is good when we get the keys
      let resultObj = responseObj["result"]
      if not resultObj.hasKey("keys"):
        raise newException(CatchableError, "login action keycard response missing keys")
      data.exportedKeys = resultObj["keys"].toKeycardExportedKeysDto()
    except Exception as e:
      error "login action error", err=e.msg
      data.error = e.msg
    self.events.emit(SIGNAL_KEYCARD_LOGIN_FINISHED, data)
  )

proc asyncRecover*(self: Service, pin: string, puk: string, mnemonic: string) {.featureGuard(KEYCARD_ENABLED).} =
  let params = %*{
    "pin": pin,
    "puk": puk,
    "pairingPassword": "", # we keep it empty for now
    "mnemonic": mnemonic,
    "storageFilePath": status_const.KEYCARDPAIRINGDATAFILE,
    "logEnabled": status_const.KEYCARD_LOGS_ENABLED,
    "logFilePath": status_const.KEYCARD_LOG_FILE_PATH,
  }
  self.asyncCallRPC(KeycardAction.Recover, params, proc (responseObj: JsonNode, err: string) =
    var data = KeycardLoginArgs()
    try:
      if err.len > 0:
        raise newException(CatchableError, "recover action parsing response error: " & err)
      if responseObj.hasKey("error") and responseObj["error"].kind != JNull:
        let errorObj = responseObj["error"]
        if errorObj.hasKey("message"):
          raise newException(CatchableError, "recover action keycard response error: " & errorObj["message"].getStr())
        raise newException(CatchableError, "recover action keycard response unknown error")
      let resultObj = responseObj["result"]
      if not resultObj.hasKey("keys"):
        raise newException(CatchableError, "recover action keycard response missing keys")
      data.exportedKeys = resultObj["keys"].toKeycardExportedKeysDto()
    except Exception as e:
      error "recover action error", err=e.msg
      data.error = e.msg
    self.events.emit(SIGNAL_KEYCARD_LOGIN_FINISHED, data)
  )

proc asyncExportPublicKey*(self: Service, keyUid: string, paths: seq[string], exportPrivate: bool, exportMasterAddr: bool,
  pin: string) {.featureGuard(KEYCARD_ENABLED).} =
  let params = %*{
    "keyUid": keyUid,
    "paths": paths,
    "exportPrivate": exportPrivate,
    "exportMasterAddr": exportMasterAddr,
    "pin": pin,
    "storageFilePath": status_const.KEYCARDPAIRINGDATAFILE,
    "logEnabled": status_const.KEYCARD_LOGS_ENABLED,
    "logFilePath": status_const.KEYCARD_LOG_FILE_PATH,
  }
  self.asyncCallRPC(KeycardAction.ExportPublicKey, params, proc (responseObj: JsonNode, err: string) =
    var data = KeycardExportedPublicKeysArgs()
    try:
      if err.len > 0:
        raise newException(CatchableError, "exporting public keys parsing response error: " & err)
      if responseObj.hasKey("error") and responseObj["error"].kind != JNull:
        let errorObj = responseObj["error"]
        if errorObj.hasKey("message"):
          raise newException(CatchableError, "exporting public keys keycard response error: " & errorObj["message"].getStr())
        raise newException(CatchableError, "exporting public keys keycard response unknown error")
      data.exportedPublicKeys = responseObj["result"].toKeycardExportedPublicKeysDto()
    except Exception as e:
      error "exporting public keys error", err=e.msg
      data.error = e.msg
    self.events.emit(SIGNAL_KEYCARD_EXPORT_PUBLIC_KEYS_FINISHED, data)
  )

proc asyncExportExtendedPublicKey*(self: Service, keyUid: string, path: string, pin: string) {.featureGuard(KEYCARD_ENABLED).} =
  let params = %*{
    "keyUid": keyUid,
    "path": path,
    "pin": pin,
    "storageFilePath": status_const.KEYCARDPAIRINGDATAFILE,
    "logEnabled": status_const.KEYCARD_LOGS_ENABLED,
    "logFilePath": status_const.KEYCARD_LOG_FILE_PATH,
  }
  self.asyncCallRPC(KeycardAction.ExportExtendedPublicKey, params, proc (responseObj: JsonNode, err: string) =
    var data = KeycardExportedExtendedPublicKeyArgs()
    try:
      if err.len > 0:
        raise newException(CatchableError, "exporting extended public keys parsing response error: " & err)
      if responseObj.hasKey("error") and responseObj["error"].kind != JNull:
        let errorObj = responseObj["error"]
        if errorObj.hasKey("message"):
          raise newException(CatchableError, "exporting extended public keys keycard response error: " & errorObj["message"].getStr())
        raise newException(CatchableError, "exporting extended public keys keycard response unknown error")
      data.exportedExtendedPublicKey = responseObj["result"].toKeycardExportedExtendedPublicKeyDto()
    except Exception as e:
      error "exporting extended public keys error", err=e.msg
      data.error = e.msg
    self.events.emit(SIGNAL_KEYCARD_EXPORT_EXTENDED_PUBLIC_KEYS_FINISHED, data)
  )

proc asyncChangeKeycardPIN*(self: Service, keyUid: string, pin: string, newPin: string) {.featureGuard(KEYCARD_ENABLED).} =
  let params = %*{
    "keyUid": keyUid,
    "pin": pin,
    "newPin": newPin,
    "storageFilePath": status_const.KEYCARDPAIRINGDATAFILE,
    "logEnabled": status_const.KEYCARD_LOGS_ENABLED,
    "logFilePath": status_const.KEYCARD_LOG_FILE_PATH,
  }
  self.asyncCallRPC(KeycardAction.ChangeKeycardPIN, params, proc (responseObj: JsonNode, err: string) =
    var data = KeycardErrorArg()
    try:
      if err.len > 0:
        raise newException(CatchableError, "change keycard PIN parsing response error: " & err)
      if responseObj.hasKey("error") and responseObj["error"].kind != JNull:
        let errorObj = responseObj["error"]
        if errorObj.hasKey("message"):
          raise newException(CatchableError, "change keycard PIN response error: " & errorObj["message"].getStr())
        raise newException(CatchableError, "change keycard PIN response unknown error")
    except Exception as e:
      error "change keycard PIN error", err=e.msg
      data.error = e.msg
    self.events.emit(SIGNAL_KEYCARD_CHANGE_PIN_FINISHED, data)
  )

proc asyncChangeKeycardPUK*(self: Service, keyUid: string, pin: string, newPuk: string) {.featureGuard(KEYCARD_ENABLED).} =
  let params = %*{
    "keyUid": keyUid,
    "pin": pin,
    "newPuk": newPuk,
    "storageFilePath": status_const.KEYCARDPAIRINGDATAFILE,
    "logEnabled": status_const.KEYCARD_LOGS_ENABLED,
    "logFilePath": status_const.KEYCARD_LOG_FILE_PATH,
  }
  self.asyncCallRPC(KeycardAction.ChangeKeycardPUK, params, proc (responseObj: JsonNode, err: string) =
    var data = KeycardErrorArg()
    try:
      if err.len > 0:
        raise newException(CatchableError, "change keycard PUK parsing response error: " & err)
      if responseObj.hasKey("error") and responseObj["error"].kind != JNull:
        let errorObj = responseObj["error"]
        if errorObj.hasKey("message"):
          raise newException(CatchableError, "change keycard PUK response error: " & errorObj["message"].getStr())
        raise newException(CatchableError, "change keycard PUK response unknown error")
    except Exception as e:
      error "change keycard PUK error", err=e.msg
      data.error = e.msg
    self.events.emit(SIGNAL_KEYCARD_CHANGE_PUK_FINISHED, data)
  )

proc asyncUnblockUsingPUK*(self: Service, keyUid: string, puk: string, newPin: string) {.featureGuard(KEYCARD_ENABLED).} =
  let params = %*{
    "keyUid": keyUid,
    "puk": puk,
    "newPin": newPin,
    "storageFilePath": status_const.KEYCARDPAIRINGDATAFILE,
    "logEnabled": status_const.KEYCARD_LOGS_ENABLED,
    "logFilePath": status_const.KEYCARD_LOG_FILE_PATH,
  }
  self.asyncCallRPC(KeycardAction.UnblockUsingPUK, params, proc (responseObj: JsonNode, err: string) =
    var data = KeycardErrorArg()
    try:
      if err.len > 0:
        raise newException(CatchableError, "unblock using PUK parsing response error: " & err)
      if responseObj.hasKey("error") and responseObj["error"].kind != JNull:
        let errorObj = responseObj["error"]
        if errorObj.hasKey("message"):
          raise newException(CatchableError, "unblock using PUK response error: " & errorObj["message"].getStr())
        raise newException(CatchableError, "unblock using PUK response unknown error")
    except Exception as e:
      error "unblock using PUK error", err=e.msg
      data.error = e.msg
    self.events.emit(SIGNAL_KEYCARD_UNBLOCK_FINISHED, data)
  )

proc asyncSign*(self: Service, keyUid: string, pin: string, txHash: string, path: string) {.featureGuard(KEYCARD_ENABLED).} =
  let params = %*{
    "keyUid": keyUid,
    "pin": pin,
    "txHash": txHash,
    "path": path,
    "storageFilePath": status_const.KEYCARDPAIRINGDATAFILE,
    "logEnabled": status_const.KEYCARD_LOGS_ENABLED,
    "logFilePath": status_const.KEYCARD_LOG_FILE_PATH,
  }
  self.asyncCallRPC(KeycardAction.Sign, params, proc (responseObj: JsonNode, err: string) =
    var data = KeycardSignArgs()
    try:
      if err.len > 0:
        raise newException(CatchableError, "sign action parsing response error: " & err)
      if responseObj.hasKey("error") and responseObj["error"].kind != JNull:
        let errorObj = responseObj["error"]
        if errorObj.hasKey("message"):
          raise newException(CatchableError, "sign action keycard response error: " & errorObj["message"].getStr())
        raise newException(CatchableError, "sign action keycard response unknown error")
      data.signature = responseObj["result"].toKeycardSignatureDto()
    except Exception as e:
      error "sign action error", err=e.msg
      data.error = e.msg
    self.events.emit(SIGNAL_KEYCARD_SIGN_FINISHED, data)
  )

proc asyncGetKeycardMetadata*(self: Service, pin: string) {.featureGuard(KEYCARD_ENABLED).} =
  let params = %*{
    "pin": pin, # optional, if provided, authorizes and resolves wallet address/publicKey for each metadata wallet path.
    "storageFilePath": status_const.KEYCARDPAIRINGDATAFILE,
    "logEnabled": status_const.KEYCARD_LOGS_ENABLED,
    "logFilePath": status_const.KEYCARD_LOG_FILE_PATH,
  }
  self.asyncCallRPC(KeycardAction.GetKeycardMetadata, params, proc (responseObj: JsonNode, err: string) =
    var data = KeycardGetKeycardMetadataArgs()
    try:
      if err.len > 0:
        raise newException(CatchableError, "get keycard metadata parsing response error: " & err)
      if responseObj.hasKey("error") and responseObj["error"].kind != JNull:
        let errorObj = responseObj["error"]
        if errorObj.hasKey("message"):
          raise newException(CatchableError, "get keycard metadata response error: " & errorObj["message"].getStr())
        raise newException(CatchableError, "get keycard metadata response unknown error")
      data.metadata = responseObj["result"].toCardMetadataDto()
    except Exception as e:
      error "get keycard metadata error", err=e.msg
      data.error = e.msg
    self.events.emit(SIGNAL_KEYCARD_GET_KEYCARD_METADATA_FINISHED, data)
  )

proc asyncFactoryResetKeycard*(self: Service) {.featureGuard(KEYCARD_ENABLED).} =
  let params = %*{}
  self.asyncCallRPC(KeycardAction.FactoryReset, params, proc (responseObj: JsonNode, err: string) =
    var data = KeycardErrorArg()
    try:
      if err.len > 0:
        raise newException(CatchableError, "factory reset parsing response error: " & err)
      if responseObj.hasKey("error") and responseObj["error"].kind != JNull:
        let errorObj = responseObj["error"]
        if errorObj.hasKey("message"):
          raise newException(CatchableError, "factory reset response error: " & errorObj["message"].getStr())
        raise newException(CatchableError, "factory reset response unknown error")
    except Exception as e:
      error "factory reset error", err=e.msg
      data.error = e.msg
    self.events.emit(SIGNAL_KEYCARD_FACTORY_RESET_KEYCARD_FINISHED, data)
  )