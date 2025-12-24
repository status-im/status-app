import nimqml, tables, os, json, std/strformat, sequtils, strutils, times, std/options
import json_serialization, chronicles

import app/global/global_singleton
import ./dto/accounts as dto_accounts
import ./dto/generated_accounts as dto_generated_accounts
import ./dto/login_request
import ./dto/restore_account_request

from ../keycard/service import KeycardEvent, KeyDetails
from ../keycardV2/dto import KeycardExportedKeysDto, KeyDetailsV2
import backend/general as status_general
import backend/core as status_core
import backend/privacy as status_privacy

import app/core/eventemitter
import app/core/signals/types
import app/core/tasks/[qt, threadpool]
import app_service/common/[account_constants, utils]
from app_service/service/contacts/dto/contacts import Images
import constants as main_constants

export dto_accounts
export dto_generated_accounts


logScope:
  topics = "accounts-service"

const ACCOUNT_ALREADY_EXISTS_ERROR* =  "account already exists"
const KDF_ITERATIONS* {.intdefine.} = 256_000
const DEFAULT_CUSTOMIZATION_COLOR = "primary"  # to match `CustomizationColor` on the go side

# allow runtime override via environment variable. core contributors can set a
# specific peer to set for testing messaging and mailserver functionality with squish.
let TEST_PEER_ENR = getEnv("TEST_PEER_ENR").string

const SIGNAL_CONVERTING_PROFILE_KEYPAIR* = "convertingProfileKeypair"
const SIGNAL_DERIVED_ADDRESSES_FROM_NOT_IMPORTED_MNEMONIC_FETCHED* = "derivedAddressesFromNotImportedMnemonicFetched"
const SIGNAL_LOGIN_ERROR* = "errorWhileLogin"

type ResultArgs* = ref object of Args
  success*: bool

type LoginErrorArgs* = ref object of Args
  error*: string

type DerivedAddressesFromNotImportedMnemonicArgs* = ref object of Args
  error*: string
  derivations*: Table[string, DerivedAccountDetails]

include utils
include async_tasks
include ../../common/async_tasks

QtObject:
  type Service* = ref object of QObject
    events: EventEmitter
    threadpool: ThreadPool
    accounts: seq[AccountDto]
    loggedInAccount: AccountDto

  proc restoreAccountAndLogin(self: Service, request: RestoreAccountRequest): string

  proc delete*(self: Service)
  proc newService*(events: EventEmitter, threadpool: ThreadPool): Service =
    new(result, delete)
    result.QObject.setup
    result.events = events
    result.threadpool = threadpool

  proc setLocalAccountSettingsFile(self: Service) =
    if self.loggedInAccount.isValid():
      singletonInstance.localAccountSettings.setFileName(self.loggedInAccount.name)

  proc getLoggedInAccount*(self: Service): AccountDto =
    return self.loggedInAccount

  proc setLoggedInAccount*(self: Service, account: AccountDto) =
    self.loggedInAccount = account
    self.setLocalAccountSettingsFile()

  proc updateLoggedInAccount*(self: Service, displayName: string, images: Images) =
    self.loggedInAccount.name = displayName
    self.loggedInAccount.images = images
    singletonInstance.localAccountSettings.setFileName(displayName)

  proc init*(self: Service) =
    discard

  proc clear*(self: Service) =
    self.loggedInAccount = AccountDto()

  proc validateMnemonic*(self: Service, mnemonic: string): (string, string) =
    try:
      let response = status_general.validateMnemonic(mnemonic)
      if response.result.contains("error"):
        return ("", response.result["error"].getStr)
      return (response.result["keyUID"].getStr, "")
    except Exception as e:
      error "error: ", procName="validateMnemonic", errName = e.name, errDesription = e.msg

  proc openedAccounts*(self: Service): seq[AccountDto] =
    if self.accounts.len > 0:
      return self.accounts

    try:
      let response = status_account.openedAccounts(main_constants.STATUSGODIR)

      self.accounts = map(response.result{"accounts"}.getElems(), proc(x: JsonNode): AccountDto = toAccountDto(x))

      return self.accounts

    except Exception as e:
      error "error: ", procName="openedAccounts", errName = e.name, errDesription = e.msg

  proc openedAccountsContainsKeyUid*(self: Service, keyUid: string): bool =
    return (keyUID in self.openedAccounts().mapIt(it.keyUid))

  proc getAccountByKeyUid*(self: Service, keyUid: string): AccountDto =
    for account in self.openedAccounts():
      if account.keyUid == keyUid:
        return account

  # FIXME: remove this method, settings should be processed in status-go
  # https://github.com/status-im/status-go/issues/5359
  proc addKeycardDetails(self: Service, kcInstance: string, settingsJson: var JsonNode, accountData: var JsonNode) =
    let keycardPairingJsonString = readFile(main_constants.KEYCARDPAIRINGDATAFILE)
    let keycardPairingJsonObj = keycardPairingJsonString.parseJSON
    let now = now().toTime().toUnix()
    for instanceUid, kcDataObj in keycardPairingJsonObj:
      if instanceUid != kcInstance:
        continue
      if not settingsJson.isNil:
        settingsJson["keycard-instance-uid"] = %* instanceUid
        settingsJson["keycard-paired-on"] = %* now
        settingsJson["keycard-pairing"] = kcDataObj{"key"}
      if not accountData.isNil:
        accountData["keycard-pairing"] = kcDataObj{"key"}

  proc toInt(value: string, defaultValue: int): int =
    try:
      return parseInt(value)
    except ValueError:
      return defaultValue

  proc buildWalletSecrets(): WalletSecretsConfig =
    return WalletSecretsConfig(
      poktToken: POKT_TOKEN_RESOLVED,
      infuraToken: INFURA_TOKEN_RESOLVED,
      infuraSecret: INFURA_TOKEN_SECRET_RESOLVED,
      openseaApiKey: OPENSEA_API_KEY_RESOLVED,
      raribleMainnetApiKey: RARIBLE_MAINNET_API_KEY_RESOLVED,
      raribleTestnetApiKey: RARIBLE_TESTNET_API_KEY_RESOLVED,
      alchemyApiKey: ALCHEMY_API_KEY_RESOLVED,
      statusProxyStageName: STATUS_PROXY_STAGE_NAME_RESOLVED,
      statusProxyMarketUser: STATUS_PROXY_USER_RESOLVED,
      statusProxyMarketPassword: STATUS_PROXY_PASSWORD_RESOLVED,
      marketDataProxyUrl: MARKET_DATA_PROXY_URL_RESOLVED,
      marketDataProxyUser: MARKET_DATA_PROXY_USER_RESOLVED,
      marketDataProxyPassword: MARKET_DATA_PROXY_PASSWORD_RESOLVED,
      statusProxyBlockchainUser: STATUS_PROXY_USER_RESOLVED,
      statusProxyBlockchainPassword: STATUS_PROXY_PASSWORD_RESOLVED,
      ethRpcProxyUser: ETH_RPC_PROXY_USER_RESOLVED,
      ethRpcProxyPassword: ETH_RPC_PROXY_PASSWORD_RESOLVED,
      ethRpcProxyUrl: ETH_RPC_PROXY_URL_RESOLVED,
    )

  proc buildWalletConfig(): WalletConfig =
    return WalletConfig(
      tokensListsAutoRefreshInterval: 0,
      tokensListsAutoRefreshCheckInterval: 0,
      marketDataFullDataRefreshInterval: toInt(MARKET_DATA_FULL_REFRESH_INTERVAL, 0),
      marketDataPriceRefreshInterval: toInt(MARKET_DATA_PRICE_REFRESH_INTERVAL, 0),
    )

  proc isMobilePlatform(): bool =
    return defined(ios) or defined(android)

  proc defaultCreateAccountRequest*(): CreateAccountRequest =
    return CreateAccountRequest(
        rootDataDir: main_constants.STATUSGODIR,
        kdfIterations: KDF_ITERATIONS,
        customizationColor: DEFAULT_CUSTOMIZATION_COLOR,
        logLevel: some(main_constants.getStatusGoLogLevel()),
        wakuV2LightClient: isMobilePlatform(),
        wakuV2EnableMissingMessageVerification: true,
        wakuV2EnableStoreConfirmationForMessagesSent: true,
        previewPrivacy: true,
        autoRefreshTokensEnabled: true,
        torrentConfigEnabled: some(false),
        torrentConfigPort: some(TORRENT_CONFIG_PORT),
        keycardPairingDataFile: main_constants.KEYCARDPAIRINGDATAFILE,
        walletSecretsConfig: buildWalletSecrets(),
        walletConfig: buildWalletConfig(),
        apiConfig: defaultApiConfig(),
      )

  proc buildCreateAccountRequest(password: string, displayName: string, imagePath: string,
    imageCropRectangle: ImageCropRectangle, thirdpartyServicesEnabled: bool): CreateAccountRequest =
    var request = defaultCreateAccountRequest()
    request.password = hashPassword(password)
    request.displayName = displayName
    request.imagePath = imagePath
    request.imageCropRectangle = imageCropRectangle
    request.thirdpartyServicesEnabled = thirdpartyServicesEnabled
    return request

  proc createAccountAndLogin*(self: Service, password: string, displayName: string,
    imagePath: string, imageCropRectangle: ImageCropRectangle, thirdpartyServicesEnabled: bool): string =
    try:
      let request = buildCreateAccountRequest(password, displayName, imagePath, imageCropRectangle, thirdpartyServicesEnabled)
      let response = status_account.createAccountAndLogin(request)

      if not response.result.contains("error"):
        error "invalid status-go response", response
        return "invalid response: no error field found"

      let error = response.result["error"].getStr
      if error == "":
        debug "Account saved succesfully"
        return ""

      error "createAccountAndLogin status-go error: ", error
      return "createAccountAndLogin failed: " & error

    except Exception as e:
      error "failed to create account or login", procName="createAccountAndLogin", errName = e.name, errDesription = e.msg
      return e.msg

  proc importAccountAndLogin*(self: Service,
    mnemonic: string,
    password: string,
    displayName: string,
    imagePath: string,
    imageCropRectangle: ImageCropRectangle,
    keycardInstanceUID: string = "",
    thirdpartyServicesEnabled: bool
  ): string =

    var request = RestoreAccountRequest(
      mnemonic: mnemonic,
      createAccountRequest: buildCreateAccountRequest(password, displayName, imagePath, imageCropRectangle, thirdpartyServicesEnabled),
    )
    request.createAccountRequest.keycardInstanceUID = keycardInstanceUID

    self.restoreAccountAndLogin(request)

  # TODO remove this function when the old keycard service is removed
  proc restoreKeycardAccountAndLogin*(self: Service,
    keycardData: KeycardEvent,
    displayName: string,
    imagePath: string,
    imageCropRectangle: ImageCropRectangle,
    thirdpartyServicesEnabled: bool
    ): string =

    let keycard = KeycardData(
      keyUid: keycardData.keyUid,
      address: keycardData.masterKey.address,
      whisperPrivateKey: keycardData.whisperKey.privateKey,
      whisperPublicKey: keycardData.whisperKey.publicKey,
      whisperAddress: keycardData.whisperKey.address,
      walletPublicKey: keycardData.walletKey.publicKey,
      walletAddress: keycardData.walletKey.address,
      walletRootAddress: keycardData.walletRootKey.address,
      eip1581Address: keycardData.eip1581Key.address,
      encryptionPublicKey: keycardData.encryptionKey.publicKey,
    )

    var request = RestoreAccountRequest(
      keycard: keycard,
      createAccountRequest: buildCreateAccountRequest("", displayName, imagePath, imageCropRectangle, thirdpartyServicesEnabled),
    )
    request.createAccountRequest.keycardInstanceUID = keycardData.instanceUid

    return self.restoreAccountAndLogin(request)

  proc restoreKeycardAccountAndLoginV2*(self: Service,
    keyUid: string,
    instanceUid: string,
    keycardKeys: KeycardExportedKeysDto,
    thirdpartyServicesEnabled: bool
    ): string =

    let keycard = KeycardData(
      keyUid: keyUid,
      address: keycardKeys.masterKey.address,
      whisperPrivateKey: keycardKeys.whisperKey.privateKey,
      whisperPublicKey: keycardKeys.whisperKey.publicKey,
      whisperAddress: keycardKeys.whisperKey.address,
      walletPublicKey: keycardKeys.walletKey.publicKey,
      walletAddress: keycardKeys.walletKey.address,
      walletRootAddress: keycardKeys.walletRootKey.address,
      eip1581Address: keycardKeys.eip1581Key.address,
      encryptionPublicKey: keycardKeys.encryptionKey.publicKey,
    )

    var request = RestoreAccountRequest(
      keycard: keycard,
      createAccountRequest: buildCreateAccountRequest(
        password = "",
        displayName = "",
        imagePath = "",
        imageCropRectangle = ImageCropRectangle(),
        thirdpartyServicesEnabled
      ),
    )
    request.createAccountRequest.keycardInstanceUID = instanceUid

    return self.restoreAccountAndLogin(request)

  proc restoreAccountAndLogin(self: Service, request: RestoreAccountRequest): string =
    try:
      let response = status_account.restoreAccountAndLogin(request)

      if not response.result.contains("error"):
        error "invalid status-go response", response
        return "invalid response: no error field found"

      let error = response.result["error"].getStr
      if error == "":
        debug "Account saved succesfully"
        return ""

      error "restoreAccountAndLogin status-go error: ", error
      return "restoreAccountAndLogin failed: " & error

    except Exception as e:
      error "restore account failed", procName="restoreAccountAndLogin", errName = e.name, errDesription = e.msg

  proc deleteMultiaccount*(self: Service, keyUid: string): string =
    try:
      let response = status_account.deleteMultiaccount(keyUid, joinPath(main_constants.ROOTKEYSTOREDIR, keyUid))

      if not response.result.contains("error"):
        error "invalid status-go response", response
        raise newException(RpcException, "invalid response: no error field found")

      let error = response.result["error"].getStr
      if error == "":
        debug "Account deleted succesfully"
        return ""

      raise newException(RpcException, error)
    except Exception as e:
      error "deleteMultiaccount failed", procName="deleteMultiaccount", errName = e.name, errDesription = e.msg
      return "deleteMultiaccount failed: " & e.msg

  proc createAccountFromPrivateKey*(self: Service, privateKey: string): GeneratedAccountDto =
    if privateKey.len == 0:
      error "empty private key"
      return
    try:
      let response = status_account.createAccountFromPrivateKey(privateKey)
      return toGeneratedAccountDto(response.result)
    except Exception as e:
      error "error: ", procName="createAccountFromPrivateKey", errName = e.name, errDesription = e.msg

  proc createAccountFromMnemonic*(self: Service, mnemonic: string, paths: seq[string]): GeneratedAccountDto =
    if mnemonic.len == 0:
      error "empty mnemonic"
      return
    try:
      let response = status_account.createAccountFromMnemonicAndDeriveAccountsForPaths(mnemonic, paths)
      return toGeneratedAccountDto(response.result)
    except Exception as e:
      error "error: ", procName="createAccountFromMnemonicAndDeriveAccountsForPaths", errName = e.name, errDesription = e.msg

  proc createAccountFromMnemonic*(self: Service, mnemonic: string, includeEncryption = false, includeWhisper = false,
    includeRoot = false, includeDefaultWallet = false, includeEip1581 = false): GeneratedAccountDto =
    var paths: seq[string]
    if includeEncryption:
      paths.add(PATH_ENCRYPTION)
    if includeWhisper:
      paths.add(PATH_WHISPER)
    if includeRoot:
      paths.add(PATH_WALLET_ROOT)
    if includeDefaultWallet:
      paths.add(PATH_DEFAULT_WALLET)
    if includeEip1581:
      paths.add(PATH_EIP_1581)
    return self.createAccountFromMnemonic(mnemonic, paths)

  proc fetchAddressesFromNotImportedMnemonic*(self: Service, mnemonic: string, paths: seq[string])=
    let arg = FetchAddressesFromNotImportedMnemonicArg(
      mnemonic: mnemonic,
      paths: paths,
      tptr: fetchAddressesFromNotImportedMnemonicTask,
      vptr: cast[uint](self.vptr),
      slot: "onAddressesFromNotImportedMnemonicFetched",
    )
    self.threadpool.start(arg)

  proc onAddressesFromNotImportedMnemonicFetched*(self: Service, jsonString: string) {.slot.} =
    var data = DerivedAddressesFromNotImportedMnemonicArgs()
    try:
      let response = parseJson(jsonString)
      data.error = response["error"].getStr()
      if data.error.len == 0:
        data.derivations = toGeneratedAccountDto(response["derivedAddresses"]).derivedAccounts.derivations
    except Exception as e:
      error "error: ", procName="fetchAddressesFromNotImportedMnemonic", errName = e.name, errDesription = e.msg
      data.error = e.msg
    self.events.emit(SIGNAL_DERIVED_ADDRESSES_FROM_NOT_IMPORTED_MNEMONIC_FETCHED, data)

  proc doLogin(self: Service, account: AccountDto, passwordHash: string, chatPrivateKey: string = "", mnemonic: string = "") =
    var request = LoginAccountRequest(
      keyUid: account.keyUid,
      kdfIterations: account.kdfIterations,
      passwordHash: passwordHash,
      keycardWhisperPrivateKey: chatPrivateKey,
      mnemonic: mnemonic,
      walletSecretsConfig: buildWalletSecrets(),
      walletConfig: buildWalletConfig(),
      bandwidthStatsEnabled: true,
      apiConfig: defaultApiConfig(),
    )

    if main_constants.runtimeLogLevelSet():
      request.runtimeLogLevel = main_constants.getStatusGoLogLevel()

    let response = status_account.loginAccount(request)

    if response.result{"error"}.getStr != "":
      self.events.emit(SIGNAL_LOGIN_ERROR, LoginErrorArgs(error: response.result{"error"}.getStr))
      return

    debug "account logged in"
    self.setLocalAccountSettingsFile()

  proc login*(self: Service, account: AccountDto, hashedPassword: string, chatPrivateKey: string = "", mnemonic: string = "") =
    try:
      self.doLogin(account, hashedPassword, chatPrivateKey, mnemonic)

    except Exception as e:
      error "login failed", errName = e.name, errDesription = e.msg
      self.events.emit(SIGNAL_LOGIN_ERROR, LoginErrorArgs(error: e.msg))

  proc convertRegularProfileKeypairToKeycard*(self: Service, keycardUid, currentPassword: string, newPassword: string) =
    var accountDataJson = %* {
      "key-uid": self.getLoggedInAccount().keyUid,
      "kdfIterations": KDF_ITERATIONS
    }
    var settingsJson = %* { }

    self.addKeycardDetails(keycardUid, settingsJson, accountDataJson)

    let hashedCurrentPassword = hashPassword(currentPassword)
    let arg = ConvertRegularProfileKeypairToKeycardTaskArg(
      tptr: convertRegularProfileKeypairToKeycardTask,
      vptr: cast[uint](self.vptr),
      slot: "onConvertRegularProfileKeypairToKeycard",
      accountDataJson: accountDataJson,
      settingsJson: settingsJson,
      keycardUid: keycardUid,
      hashedCurrentPassword: hashedCurrentPassword,
      newPassword: newPassword
    )

    DB_BLOCKED_DUE_TO_PROFILE_MIGRATION = true
    self.threadpool.start(arg)

  proc onConvertRegularProfileKeypairToKeycard*(self: Service, response: string) {.slot.} =
    var result = false
    try:
      let rpcResponse = Json.decode(response, RpcResponse[JsonNode])
      if(rpcResponse.result.contains("error")):
        let errMsg = rpcResponse.result["error"].getStr
        if(errMsg.len == 0):
          result = true
        else:
          error "error: ", procName="onConvertRegularProfileKeypairToKeycard", errDesription = errMsg
    except Exception as e:
      error "error handilng migrated keypair response", procName="onConvertRegularProfileKeypairToKeycard", errDesription=e.msg
    self.events.emit(SIGNAL_CONVERTING_PROFILE_KEYPAIR, ResultArgs(success: result))

  proc convertKeycardProfileKeypairToRegular*(self: Service, mnemonic: string, currentPassword: string, newPassword: string) =
    let hashedNewPassword = hashPassword(newPassword)
    let arg = ConvertKeycardProfileKeypairToRegularTaskArg(
      tptr: convertKeycardProfileKeypairToRegularTask,
      vptr: cast[uint](self.vptr),
      slot: "onConvertKeycardProfileKeypairToRegular",
      mnemonic: mnemonic,
      currentPassword: currentPassword,
      hashedNewPassword: hashedNewPassword
    )

    DB_BLOCKED_DUE_TO_PROFILE_MIGRATION = true
    self.threadpool.start(arg)

  proc onConvertKeycardProfileKeypairToRegular*(self: Service, response: string) {.slot.} =
    var result = false
    try:
      let rpcResponse = Json.decode(response, RpcResponse[JsonNode])
      if(rpcResponse.result.contains("error")):
        let errMsg = rpcResponse.result["error"].getStr
        if(errMsg.len == 0):
          result = true
        else:
          error "failed to convert keycard account", procName="onConvertKeycardProfileKeypairToRegular", errDesription = errMsg
    except Exception as e:
      error "error handilng migrated keypair response", procName="onConvertKeycardProfileKeypairToRegular", errDesription=e.msg
    self.events.emit(SIGNAL_CONVERTING_PROFILE_KEYPAIR, ResultArgs(success: result))

  proc verifyPassword*(self: Service, password: string): bool =
    try:
      let hashedPassword = hashPassword(password)
      let response = status_account.verifyPassword(hashedPassword)
      return response.result.getBool
    except Exception as e:
      error "error: ", procName="verifyPassword", errName = e.name, errDesription = e.msg
    return false

  proc getKdfIterations*(self: Service): int =
    return KDF_ITERATIONS

  proc delete*(self: Service) =
    self.QObject.delete

