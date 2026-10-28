#################################################
# Async convert profile keypair from regular to keycard keypair
#################################################

type
  ConvertRegularProfileKeypairToKeycardTaskArg* = ref object of QObjectTaskArg
    accountDataJson: JsonNode
    settingsJson: JsonNode
    keycardUid: string
    hashedCurrentPassword: string
    newPassword: string
    keycardSecureChannelV2: bool

proc convertRegularProfileKeypairToKeycardTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[ConvertRegularProfileKeypairToKeycardTaskArg](argEncoded)
  try:
    var errMsg: string
    if arg.accountDataJson.isNil or arg.settingsJson.isNil:
      errMsg = "at least one json object is not prepared well"
    elif arg.keycardUid.len == 0:
      errMsg = "provided keycardUid must not be empty"
    elif arg.hashedCurrentPassword.len == 0:
      errMsg = "provided password must not be empty"
    elif arg.newPassword.len == 0:
      errMsg = "provided new password must not be empty"

    var response: RpcResponse[JsonNode]
    if errMsg.len > 0:
      response.result = newJNull()
      response.error = RpcError(message: errMsg)
      error "error: ", errDescription=errMsg
    else:
      response = status_account.convertRegularProfileKeypairToKeycard(arg.accountDataJson, arg.settingsJson,
      arg.keycardUid, arg.hashedCurrentPassword, arg.newPassword, arg.keycardSecureChannelV2)
    arg.finish(response)
  except Exception as e:
    error "error converting profile keypair to keycard keypair: ", errDescription=e.msg
    arg.finish("")

#################################################
# Async convert profile keypair from keycard to regular keypair
#################################################

type
  ConvertKeycardProfileKeypairToRegularTaskArg* = ref object of QObjectTaskArg
    mnemonic: string
    currentPassword: string
    hashedNewPassword: string

proc convertKeycardProfileKeypairToRegularTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[ConvertKeycardProfileKeypairToRegularTaskArg](argEncoded)
  try:
    var response: RpcResponse[JsonNode]
    if arg.mnemonic.len == 0:
      response.error.message = "provided mnemonic must not be empty"
      error "error: ", errDescription=response.error.message
    elif arg.currentPassword.len == 0:
      response.error.message = "provided password must not be empty"
      error "error: ", errDescription=response.error.message
    elif arg.hashedNewPassword.len == 0:
      response.error.message = "provided new password must not be empty"
      error "error: ", errDescription=response.error.message
    else:
      response = status_account.convertKeycardProfileKeypairToRegular(arg.mnemonic, arg.currentPassword, arg.hashedNewPassword)
    arg.finish(response)
  except Exception as e:
    error "error converting profile keypair to regular keypair: ", errDescription=e.msg
    arg.finish("")


#################################################
# Async load derived addreses
#################################################

type
  FetchAddressesFromNotImportedMnemonicArg* = ref object of QObjectTaskArg
    mnemonic: string
    paths: seq[string]

proc fetchAddressesFromNotImportedMnemonicTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[FetchAddressesFromNotImportedMnemonicArg](argEncoded)
  var output = %*{
    "derivedAddress": "",
    "error": ""
  }
  try:
    let response = status_account.createAccountFromMnemonicAndDeriveAccountsForPaths(arg.mnemonic, arg.paths)
    output["derivedAddresses"] = response.result
  except Exception as e:
    output["error"] = %* fmt"Error fetching address from not imported mnemonic: {e.msg}"
  arg.finish(output)