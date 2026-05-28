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
  BuildTokensTaskArg = ref object of QObjectTaskArg
    accounts: seq[string]
    forceRefresh: bool

proc prepareTokensTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[BuildTokensTaskArg](argEncoded)
  var output = %*{
    "result": ""
  }
  try:
    let response = backend.fetchOrGetCachedWalletBalances(arg.accounts, arg.forceRefresh)
    output["result"] = response.result
  except Exception as e:
    let err = fmt"Error getting wallet tokens"
  arg.finish(output)

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
