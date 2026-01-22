#################################################
# Async load derivedAddreses
#################################################
type
  FetchAddressesArg* = ref object of QObjectTaskArg
    paths: seq[string]

type
  FetchDerivedAddressesTaskArg* = ref object of FetchAddressesArg
    password: string
    derivedFrom: string

proc fetchDerivedAddressesTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[FetchDerivedAddressesTaskArg](argEncoded)
  var output = %*{
    "derivedAddresses": "",
    "error": ""
  }
  try:
    let response = status_go_accounts.getDerivedAddresses(arg.password, arg.derivedFrom, arg.paths)
    output["derivedAddresses"] = response.result
  except Exception as e:
    output["error"] = %* fmt"Error fetching derived address: {e.msg}"
  arg.finish(output)

type
  FetchDerivedAddressesForMnemonicTaskArg* = ref object of FetchAddressesArg
    mnemonic: string

proc fetchDerivedAddressesForMnemonicTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[FetchDerivedAddressesForMnemonicTaskArg](argEncoded)
  var output = %*{
    "derivedAddresses": "",
    "error": ""
  }
  try:
    let response = status_go_accounts.getDerivedAddressesForMnemonic(arg.mnemonic, arg.paths)
    output["derivedAddresses"] = response.result
  except Exception as e:
    output["error"] = %* fmt"Error fetching derived address for mnemonic: {e.msg}"
  arg.finish(output)

type
  FetchDetailsForAddressTaskArg* = ref object of QObjectTaskArg
    uniqueId: string
    address: string

proc fetchDetailsForAddressTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[FetchDetailsForAddressTaskArg](argEncoded)
  var jsonReponse = %* {
    "address": arg.address,
    "alreadyCreated": false,
    "path": "",
    "hasActivity": false
  }
  var data = %* {
    "uniqueId": arg.uniqueId,
    "details": jsonReponse,
    "error": ""
  }
  try:
    let response = status_go_accounts.getAddressDetails(arg.address, chainIds = @[], timeoutInMilliseconds = 3000)
    if not response.error.isNil:
      raise newException(CatchableError, response.error.message)
    data["details"] = response.result
  except Exception as e:
    let err = fmt"Error fetching details for an address: {e.msg}"
    data["error"] = %* err
  arg.finish(data)

#################################################
# Async building token
#################################################

type
  GetAllTokenBalancesTaskArg = ref object of QObjectTaskArg
    accounts: seq[string]
    chainIds: seq[int]

proc getAllTokenBalancesTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[GetAllTokenBalancesTaskArg](argEncoded)
  var output = %*{
    "result": ""
  }
  try:
    let response = backend.getAllTokenBalances(arg.chainIds, arg.accounts)
    output["result"] = response.result
  except Exception as e:
    let err = fmt"Error getting wallet tokens: {e.msg}"
  arg.finish(output)

#################################################
# Async add new keycard or accounts
#################################################

type
  SaveOrUpdateKeycardTaskArg* = ref object of QObjectTaskArg
    keycard: KeycardDto
    password: string

proc saveOrUpdateKeycardTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[SaveOrUpdateKeycardTaskArg](argEncoded)
  var responseJson = %*{
    "success": false,
    "keycard": arg.keycard.toJsonNode()
  }
  try:
    let response = backend.saveOrUpdateKeycard(
      %* {
        "keycard-uid": arg.keycard.keycardUid,
        "keycard-name": arg.keycard.keycardName,
        # "keycard-locked" - no need to set it here, cause it will be set to false by the status-go
        "key-uid": arg.keycard.keyUid,
        "accounts-addresses": arg.keycard.accountsAddresses,
        # "position": - no need to set it here, cause it is fully maintained by the status-go
      },
      arg.password
      )
    let success = responseHasNoErrors("saveOrUpdateKeycard", response)
    responseJson["success"] = %* success
  except Exception as e:
    error "error adding new keycard: ", message = e.msg
  arg.finish(responseJson)

#################################################
# Async remove migrated accounts for keycard
#################################################

type
  DeleteKeycardAccountsTaskArg* = ref object of QObjectTaskArg
    keycard: KeycardDto

proc deleteKeycardAccountsTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[DeleteKeycardAccountsTaskArg](argEncoded)
  var responseJson = %*{
    "success": false,
    "keycard": arg.keycard.toJsonNode()
  }
  try:
    let response = backend.deleteKeycardAccounts(
      arg.keycard.keycardUid,
      arg.keycard.accountsAddresses
      )
    let success = responseHasNoErrors("deleteKeycardAccounts", response)
    responseJson["success"] = %* success
  except Exception as e:
    error "error remove accounts from keycard: ", message = e.msg

  arg.finish(responseJson)

#################################################
# Async fetch chain id for url
#################################################

type
  FetchChainIdForUrlTaskArg* = ref object of QObjectTaskArg
    url: string
    isMainUrl: bool

proc fetchChainIdForUrlTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[FetchChainIdForUrlTaskArg](argEncoded)
  try:
    let response = status_go_network.fetchChainIDForURL(arg.url)
    arg.finish(%*{
      "success": true,
      "chainId": response.result.getInt,
      "url": arg.url,
      "isMainUrl": arg.isMainUrl
    })
  except Exception as e:
    error "error when fetching chaind id from url: ", message = e.msg
    arg.finish(%*{
      "success": false,
      "chainId": -1,
      "url": arg.url,
      "isMainUrl": arg.isMainUrl
    })

#################################################
# Async migration of a non profile keycard keypair to the app
#################################################

type
  MigrateNonProfileKeycardKeypairToAppTaskArg* = ref object of QObjectTaskArg
    keyUid: string
    seedPhrase: string
    password: string

proc migrateNonProfileKeycardKeypairToAppTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[MigrateNonProfileKeycardKeypairToAppTaskArg](argEncoded)
  var responseJson = %*{
    "success": false,
    "keyUid": arg.keyUid
  }
  try:
    let response = status_go_accounts.migrateNonProfileKeycardKeypairToApp(arg.seedPhrase, arg.password)
    let success = responseHasNoErrors("migrateNonProfileKeycardKeypairToApp", response)
    responseJson["success"] = %* success
  except Exception as e:
    error "error migrating a non profile keycard keypair: ", message = e.msg
  arg.finish(responseJson)

#################################################
# Async fetching of token balances for a given account(s)
#################################################

type
  BalanceHistoryTimeInterval* {.pure.} = enum
    BalanceHistory7Hours = 0,
    BalanceHistory1Month,
    BalanceHistory6Months,
    BalanceHistory1Year,
    BalanceHistoryAllTime

#################################################
# Async get ENS names for account
#################################################

type
  FetchENSNamesForAddressesTaskArg = ref object of QObjectTaskArg
    chainId: int
    addresses: seq[string]

proc fetchENSNamesForAddressesTask*(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[FetchENSNamesForAddressesTaskArg](argEncoded)
  var response = %* {
    "result": [],
    "error": "",
  }
  try:
    var result = newJobject()
    for address in arg.addresses:
      let name = getEnsName(address, arg.chainId)
      result[address] = %name
    response["result"] = result
  except Exception as e:
    response["error"] = %* e.msg
  arg.finish(response)
