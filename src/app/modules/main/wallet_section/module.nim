import nimqml, json, chronicles, sequtils, strutils, sugar

import ./controller, ./view, ./filter
import ./io_interface as io_interface
import ../io_interface as delegate_interface

import ./accounts/module as accounts_module
import ./all_tokens/module as all_tokens_module
import ./all_collectibles/module as all_collectibles_module
import ./assets/module as assets_module
import ./saved_addresses/module as saved_addresses_module
import ./following_addresses/module as following_addresses_module
import ./buy_sell_crypto/module as buy_sell_crypto_module
import ./networks/module as networks_module
import ./overview/module as overview_module
import ./send/module as send_module
import ./send_new/module as new_send_module

import ./activity/controller as activityc

import app/modules/shared_modules/collectible_details/controller as collectible_detailsc
import app/modules/shared_modules/wallet_connect/controller as wc_controller
import app/modules/shared_modules/connector/controller as connector_controller

import app/global/global_singleton
import app/core/eventemitter
import app/modules/shared_modules/add_account/module as add_account_module
import app/modules/shared_modules/keypair_import/module as keypair_import_module
import app_service/service/keycard/service as keycard_service
import app_service/service/token/service as token_service
import app_service/service/collectible/service as collectible_service
import app_service/service/currency/service as currency_service
import app_service/service/ramp/service as ramp_service
import app_service/service/transaction/service as transaction_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/settings/service as settings_service
import app_service/service/saved_address/service as saved_address_service
import app_service/service/following_address/service as following_address_service
import app_service/service/network/service as network_service
import app_service/service/accounts/service as accounts_service
import app_service/service/node/service as node_service
import app_service/service/network_connection/service as network_connection_service
import app_service/service/devices/service as devices_service
import app_service/service/community_tokens/service as community_tokens_service
import app_service/service/wallet_connect/service as wc_service
import app_service/service/connector/service as connector_service

import backend/collectibles as backend_collectibles

import app/core/tasks/threadpool

logScope:
  topics = "wallet-section-module"

export io_interface

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    events: EventEmitter
    moduleLoaded: bool
    controller: controller.Controller
    view: View
    viewVariant: QVariant
    filter: Filter

    # shared modules
    addAccountModule: add_account_module.AccessInterface
    keypairImportModule: keypair_import_module.AccessInterface
    # modules
    accountsModule: accounts_module.AccessInterface
    allTokensModule: all_tokens_module.AccessInterface
    allCollectiblesModule: all_collectibles_module.AccessInterface
    assetsModule: assets_module.AccessInterface
    sendModule: send_module.AccessInterface
    # TODO: replace this with sendModule when old one is removed
    newSendModule: new_send_module.AccessInterface
    savedAddressesModule: saved_addresses_module.AccessInterface
    followingAddressesModule: following_addresses_module.AccessInterface
    buySellCryptoModule: buy_sell_crypto_module.AccessInterface
    overviewModule: overview_module.AccessInterface
    networksModule: networks_module.AccessInterface
    networksService: network_service.Service
    rampService: ramp_service.Service
    transactionService: transaction_service.Service
    keycardService: keycard_service.Service
    accountsService: accounts_service.Service
    walletAccountService: wallet_account_service.Service
    savedAddressService: saved_address_service.Service
    followingAddressService: following_address_service.Service
    devicesService: devices_service.Service
    walletConnectService: wc_service.Service
    walletConnectController: wc_controller.Controller
    dappsConnectorService: connector_service.Service
    dappsConnectorController: connector_controller.Controller

    activityController: activityc.Controller
    collectibleDetailsController: collectible_detailsc.Controller
    # Instances to be used in temporary, short-lived, workflows (e.g. send popup). There's probably tidier ways of
    # doing this (one for each required module, create them dynamically) but for now this will do.
    # We need one for each app "layer" that simultaneously needs to show a different list of activity
    # entries (e.g. send popup is one "layer" above the collectible details activity tab)
    tmpActivityControllers: ActivityControllerArray

    threadpool: ThreadPool

## Forward declaration
proc onUpdatedKeypairsOperability*(self: Module, updatedKeypairs: seq[KeypairDto])
proc onLocalPairingStatusUpdate*(self: Module, data: LocalPairingStatus)

proc newModule*(
  delegate: delegate_interface.AccessInterface,
  events: EventEmitter,
  tokenService: token_service.Service,
  collectibleService: collectible_service.Service,
  currencyService: currency_service.Service,
  rampService: ramp_service.Service,
  transactionService: transaction_service.Service,
  walletAccountService: wallet_account_service.Service,
  settingsService: settings_service.Service,
  savedAddressService: saved_address_service.Service,
  followingAddressService: following_address_service.Service,
  networkService: network_service.Service,
  accountsService: accounts_service.Service,
  keycardService: keycard_service.Service,
  nodeService: node_service.Service,
  networkConnectionService: network_connection_service.Service,
  devicesService: devices_service.Service,
  communityTokensService: community_tokens_service.Service,
  threadpool: ThreadPool
): Module =
  result = Module()
  result.delegate = delegate
  result.events = events
  result.keycardService = keycardService
  result.accountsService = accountsService
  result.walletAccountService = walletAccountService
  result.savedAddressService = savedAddressService
  result.followingAddressService = followingAddressService
  result.devicesService = devicesService
  result.moduleLoaded = false
  result.controller = newController(result, settingsService, walletAccountService, currencyService, networkService)
  result.threadpool = threadpool

  result.accountsModule = accounts_module.newModule(result, events, walletAccountService, networkService, currencyService)
  result.allTokensModule = all_tokens_module.newModule(result, events, tokenService, walletAccountService, settingsService, communityTokensService)
  let allCollectiblesModule = all_collectibles_module.newModule(result, events, collectibleService, networkService, walletAccountService, settingsService)
  result.allCollectiblesModule = allCollectiblesModule
  result.assetsModule = assets_module.newModule(result, events, walletAccountService, networkService, tokenService,
    currencyService)
  result.sendModule = send_module.newModule(result, events, tokenService, walletAccountService, networkService, currencyService,
  transactionService, keycardService)
  result.newSendModule = newSendModule.newModule(result, events, walletAccountService, networkService, transactionService, keycardService)
  result.savedAddressesModule = saved_addresses_module.newModule(result, events, savedAddressService)
  result.followingAddressesModule = following_addresses_module.newModule(result, events, followingAddressService)
  result.buySellCryptoModule = buy_sell_crypto_module.newModule(result, events, rampService)
  result.overviewModule = overview_module.newModule(result, events, walletAccountService, currencyService)
  result.networksModule = networks_module.newModule(result, events, networkService, walletAccountService, settingsService)
  result.networksService = networkService

  result.transactionService = transactionService
  result.activityController = activityc.newController(
    currencyService,
    tokenService,
    savedAddressService,
    networkService,
    events)
  result.tmpActivityControllers = [
    activityc.newController(
      currencyService,
      tokenService,
      savedAddressService,
      networkService,
      events),
    activityc.newController(
      currencyService,
      tokenService,
      savedAddressService,
      networkService,
      events)
  ]

  result.collectibleDetailsController = collectible_detailsc.newController(int32(backend_collectibles.CollectiblesRequestID.WalletAccount), networkService, events)
  result.filter = initFilter(result.controller)

  result.walletConnectService = wc_service.newService(result.events, result.threadpool, settingsService, transactionService, keycardService)
  result.walletConnectController = wc_controller.newController(result.walletConnectService, walletAccountService, result.events)

  result.dappsConnectorService = connector_service.newService(result.events, result.threadpool)
  result.dappsConnectorController = connector_controller.newController(result.dappsConnectorService, result.events)
  result.view = newView(result, result.activityController, result.tmpActivityControllers, result.collectibleDetailsController, result.walletConnectController, result.dappsConnectorController)
  result.viewVariant = newQVariant(result.view)

method delete*(self: Module) =
  self.accountsModule.delete
  self.allTokensModule.delete
  self.allCollectiblesModule.delete
  self.assetsModule.delete
  self.savedAddressesModule.delete
  self.followingAddressesModule.delete
  self.buySellCryptoModule.delete
  self.sendModule.delete
  self.newSendModule.delete
  self.controller.delete
  self.viewVariant.delete
  self.view.delete
  self.activityController.delete
  for i in 0..self.tmpActivityControllers.len-1:
    self.tmpActivityControllers[i].delete
  self.collectibleDetailsController.delete

  if not self.addAccountModule.isNil:
    self.addAccountModule.delete
  if not self.keypairImportModule.isNil:
    self.keypairImportModule.delete

method updateCurrency*(self: Module, currency: string) =
  self.controller.updateCurrency(currency)

method getCurrentCurrency*(self: Module): string =
  self.controller.getCurrency()

proc getWalletAddressesNotHidden(self: Module): seq[string] =
  let walletAccounts = self.controller.getWalletAccounts()
  return walletAccounts.filter(a => not a.hideFromTotalBalance).map(a => a.address)

method setTotalCurrencyBalance*(self: Module) =
  let addresses = self.getWalletAddressesNotHidden()
  self.view.setTotalCurrencyBalance(self.controller.getTotalCurrencyBalance(addresses, self.filter.chainIds))

proc notifyModulesOnFilterChanged(self: Module) =
  self.overviewModule.filterChanged(self.filter.addresses, self.filter.chainIds)
  self.accountsModule.filterChanged(self.filter.chainIds)
  self.sendModule.filterChanged(self.filter.addresses, self.filter.chainIds, self.filter.isDirty)
  self.activityController.globalFilterChanged(self.filter.addresses, self.filter.chainIds, self.filter.allChainsEnabled)
  self.allTokensModule.filterChanged(self.filter.addresses)
  self.allCollectiblesModule.refreshWalletAccounts()
  self.assetsModule.filterChanged(self.filter.addresses, self.filter.chainIds)
  self.filter.isDirty = false

proc notifyModulesBalanceIsLoaded(self: Module) =
  self.overviewModule.filterChanged(self.filter.addresses, self.filter.chainIds)

proc updateViewWithAddressFilterChanged(self: Module) =
  if self.overviewModule.getIsAllAccounts():
    self.view.filterChanged("")
  else:
    self.view.filterChanged(self.view.getAddressFilters())

proc notifyFilterChanged(self: Module) =
  self.updateViewWithAddressFilterChanged()
  self.notifyModulesOnFilterChanged()

method getCurrencyAmount*(self: Module, amount: float64, key: string): CurrencyAmount =
  return self.controller.getCurrencyAmount(amount, key)

proc setKeypairOperabilityForObservedAccount(self: Module, address: string) =
  let keypair = self.controller.getKeypairByAccountAddress(address)
  if keypair.isNil:
    self.view.setKeypairOperabilityForObservedAccount("")
  else:
    self.view.setKeypairOperabilityForObservedAccount(keypair.getOperability())

method setFilterAddress*(self: Module, address: string) =
  self.setKeypairOperabilityForObservedAccount(address)
  self.filter.setAddress(address)
  self.allCollectiblesModule.setSelectedAccount(address)
  self.overviewModule.setIsAllAccounts(false)
  self.view.setAddressFilters(address)
  self.notifyFilterChanged()

method setFilterAllAddresses*(self: Module) =
  self.view.setKeypairOperabilityForObservedAccount("")
  self.filter.setAddresses(self.getWalletAddressesNotHidden())
  self.allCollectiblesModule.setSelectedAccount("")
  self.view.setAddressFilters(self.filter.addresses.join(":"))
  self.overviewModule.setIsAllAccounts(true)
  self.notifyFilterChanged()

method load*(self: Module) =
  singletonInstance.engine.setRootContextProperty("walletSection", self.viewVariant)

  self.events.on(SIGNAL_KEYPAIR_SYNCED) do(e: Args):
    let args = KeypairArgs(e)
    self.setTotalCurrencyBalance()
    for acc in args.keypair.accounts:
      if acc.removed:
        self.filter.removeAddress(acc.address)
    self.notifyFilterChanged()
  self.events.on(SIGNAL_WALLET_ACCOUNT_UPDATED) do(e:Args):
    self.notifyFilterChanged()
  self.events.on(SIGNAL_WALLET_ACCOUNT_SAVED) do(e:Args):
    let args = AccountArgs(e)
    self.setTotalCurrencyBalance()
    self.setFilterAddress(args.account.address)
  self.events.on(SIGNAL_WALLET_ACCOUNT_DELETED) do(e:Args):
    let args = AccountArgs(e)
    self.setTotalCurrencyBalance()
    self.filter.removeAddress(args.account.address)
    self.view.emitWalletAccountRemoved(args.account.address)
    if(cmpIgnoreCase(self.view.getAddressFilters(), args.account.address) == 0):
      self.setFilterAllAddresses()
    else:
      self.notifyFilterChanged()
  self.events.on(SIGNAL_WALLET_ACCOUNT_NETWORK_ENABLED_UPDATED) do(e:Args):
    self.filter.updateNetworks()
    self.setTotalCurrencyBalance()
    self.notifyFilterChanged()
  self.events.on(SIGNAL_WALLET_ACCOUNT_TOKENS_REBUILT) do(e:Args):
    let args = TokensPerAccountArgs(e)
    self.setTotalCurrencyBalance()
    self.notifyModulesBalanceIsLoaded()
    self.view.setLastReloadTimestamp(args.timestamp)
    self.view.setIsAccountTokensReloading(false)
  self.events.on(SIGNAL_TOKENS_MARKET_VALUES_UPDATED) do(e:Args):
    self.setTotalCurrencyBalance()
    self.notifyFilterChanged()
  self.events.on(SIGNAL_CURRENCY_FORMATS_UPDATED) do(e:Args):
    self.setTotalCurrencyBalance()
    self.notifyFilterChanged()
  self.events.on(SIGNAL_NEW_KEYCARD_SET) do(e: Args):
    let args = KeycardArgs(e)
    if not args.success:
      return
    self.notifyFilterChanged()
  self.events.on(SIGNAL_ALL_KEYCARDS_DELETED) do(e: Args):
    let args = KeycardArgs(e)
    if not args.success:
      return
    self.notifyFilterChanged()
  self.events.on(SIGNAL_WALLET_ACCOUNT_POSITION_UPDATED) do(e:Args):
    self.notifyFilterChanged()
  self.events.on(SIGNAL_HISTORY_NON_ARCHIVAL_NODE) do (e:Args):
    self.view.setIsNonArchivalNode(true)
  self.events.on(SIGNAL_TRANSACTION_DECODED) do(e: Args):
    let args = TransactionDecodedArgs(e)
    self.view.txDecoded(args.txHash, args.dataDecoded)
  self.events.on(SIGNAL_IMPORTED_KEYPAIRS) do(e:Args):
    let args = KeypairsArgs(e)
    if args.error.len != 0:
      return
    self.onUpdatedKeypairsOperability(args.keypairs)
  self.events.on(SIGNAL_LOCAL_PAIRING_STATUS_UPDATE) do(e:Args):
    let data = LocalPairingStatus(e)
    self.onLocalPairingStatusUpdate(data)
  self.events.on(SIGNAL_WALLET_ACCOUNT_HIDDEN_UPDATED) do(e: Args):
    if self.overviewModule.getIsAllAccounts():
      self.filter.setAddresses(self.getWalletAddressesNotHidden())
      self.view.setAddressFilters(self.filter.addresses.join(":"))
    self.notifyFilterChanged()
    self.setTotalCurrencyBalance()

  self.events.on(SIGNAL_CURRENCY_UPDATED) do(e:Args):
    let args = SettingsTextValueArgs(e)
    self.view.setCurrentCurrency(args.value)

  self.controller.init()
  self.view.load()
  self.accountsModule.load()
  self.allTokensModule.load()
  self.allCollectiblesModule.load()
  self.assetsModule.load()
  self.savedAddressesModule.load()
  self.followingAddressesModule.load()
  self.buySellCryptoModule.load()
  self.overviewModule.load()
  self.sendModule.load()
  self.newSendModule.load()
  self.networksModule.load()
  self.walletConnectService.init()
  self.walletConnectController.init()
  self.dappsConnectorService.init()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

proc checkIfModuleDidLoad(self: Module) =
  if(not self.accountsModule.isLoaded()):
    return

  if(not self.allTokensModule.isLoaded()):
    return

  if(not self.allCollectiblesModule.isLoaded()):
    return

  if(not self.assetsModule.isLoaded()):
    return

  if(not self.savedAddressesModule.isLoaded()):
    return

  if(not self.followingAddressesModule.isLoaded()):
    return

  if(not self.buySellCryptoModule.isLoaded()):
    return

  if(not self.overviewModule.isLoaded()):
    return

  if(not self.sendModule.isLoaded()):
    return

  if(not self.newSendModule.isLoaded()):
    return

  if(not self.networksModule.isLoaded()):
    return

  self.setTotalCurrencyBalance()
  self.filter.setAddresses(self.getWalletAddressesNotHidden())
  self.filter.load()
  self.notifyFilterChanged()
  self.accountsModule.loadAllWalletAccounts()
  self.moduleLoaded = true
  self.delegate.walletSectionDidLoad()
  self.view.setWalletReady()

method viewDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method accountsModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method allTokensModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method allCollectiblesModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method collectiblesModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method assetsModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method transactionsModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method savedAddressesModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method followingAddressesModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method buySellCryptoModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method overviewModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method sendModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method newSendModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method networksModuleDidLoad*(self: Module) =
  self.checkIfModuleDidLoad()

method destroyAddAccountPopup*(self: Module) =
  if self.addAccountModule.isNil:
    return

  self.view.emitDestroyAddAccountPopup()
  self.addAccountModule.delete
  self.addAccountModule = nil

method runAddAccountPopup*(self: Module, addingWatchOnlyAccount: bool) =
  self.destroyAddAccountPopup()
  self.addAccountModule = add_account_module.newModule(self, self.events, self.keycardService, self.accountsService,
    self.walletAccountService, self.savedAddressService)
  self.addAccountModule.loadForAddingAccount(addingWatchOnlyAccount)

method runEditAccountPopup*(self: Module, address: string) =
  self.destroyAddAccountPopup()
  self.addAccountModule = add_account_module.newModule(self, self.events, self.keycardService, self.accountsService,
    self.walletAccountService, self.savedAddressService)
  self.addAccountModule.loadForEditingAccount(address)

method getAddAccountModule*(self: Module): QVariant =
  if self.addAccountModule.isNil:
    return newQVariant()
  return self.addAccountModule.getModuleAsVariant()

method onAddAccountModuleLoaded*(self: Module) =
  self.view.emitDisplayAddAccountPopup()

method fetchDecodedTxData*(self: Module, txHash: string, data: string) =
  self.transactionService.fetchDecodedTxData(txHash, data)

proc onUpdatedKeypairsOperability*(self: Module, updatedKeypairs: seq[KeypairDto]) =
  if self.filter.addresses.len != 1:
    return
  for kp in updatedKeypairs:
    for acc in kp.accounts:
      if cmpIgnoreCase(acc.address, self.filter.addresses[0]) == 0:
        self.view.setKeypairOperabilityForObservedAccount(kp.getOperability())
        return

method destroyKeypairImportPopup*(self: Module) =
  if self.keypairImportModule.isNil:
    return
  self.view.emitDestroyKeypairImportPopup()
  self.keypairImportModule.delete
  self.keypairImportModule = nil
  self.view.emitKeypairImportModuleChangedSignal()

method runKeypairImportPopup*(self: Module) =
  if self.filter.addresses.len != 1:
    return
  let keypair = self.controller.getKeypairByAccountAddress(self.filter.addresses[0])
  if keypair.isNil:
    return
  self.keypairImportModule = keypair_import_module.newModule(self, self.events, self.accountsService,
    self.walletAccountService, self.devicesService)
  self.keypairImportModule.load(keypair.keyUid, ImportKeypairModuleMode.SelectImportMethod)
  self.view.emitKeypairImportModuleChangedSignal()

method getKeypairImportModule*(self: Module): QVariant =
  if self.keypairImportModule.isNil:
    return newQVariant()
  return self.keypairImportModule.getModuleAsVariant()

method onKeypairImportModuleLoaded*(self: Module) =
  self.view.emitDisplayKeypairImportPopup()

method hasPairedDevices*(self: Module): bool =
  return self.controller.hasPairedDevices()

proc onLocalPairingStatusUpdate*(self: Module, data: LocalPairingStatus) =
  if data.state == LocalPairingState.Finished:
    self.view.emitHasPairedDevicesChangedSignal()

method getRpcStats*(self: Module): string =
  return self.view.getRpcStats()

method resetRpcStats*(self: Module) =
  self.view.resetRpcStats()

method canProfileProveOwnershipOfProvidedAddresses*(self: Module, addresses: string): bool =
  var addressesForProvingOwnership: seq[string]
  try:
    addressesForProvingOwnership = map(parseJson(addresses).getElems(), proc(x:JsonNode):string = x.getStr())
  except Exception as e:
    error "Failed to parse addresses for proving ownership: ", msg=e.msg
    return false

  for address in addressesForProvingOwnership:
    let keypair = self.controller.getKeypairByAccountAddress(address)
    if keypair.isNil:
      return false
    if keypair.keyUid == singletonInstance.userProfile.getKeyUid():
      continue
    if keypair.migratedToColdWallet():
      return false
  return true

method reloadAccountTokens*(self: Module) =
  self.view.setIsAccountTokensReloading(true)
  self.controller.reloadAccountTokens()

method isChecksumValidForAddress*(self: Module, address: string): bool =
  return self.controller.isChecksumValidForAddress(address)
