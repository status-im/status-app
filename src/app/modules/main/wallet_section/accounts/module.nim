import nimqml, json, sequtils, sugar, tables

import ./io_interface, ./view, ./controller
import ./item as wallet_accounts_item
import ../io_interface as delegate_interface
import app/global/global_singleton
import app/core/eventemitter
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/network/service as network_service
import app_service/service/currency/service as currency_service
import app_service/service/token/service as token_service
import app/modules/shared/wallet_utils

export io_interface

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    events: EventEmitter
    view: View
    viewVariant: QVariant
    controller: Controller
    moduleLoaded: bool
    walletAccountService: wallet_account_service.Service
    filterChainIds: seq[int]

proc newModule*(
  delegate: delegate_interface.AccessInterface,
  events: EventEmitter,
  walletAccountService: wallet_account_service.Service,
  networkService: network_service.Service,
  currencyService: currency_service.Service
): Module =
  result = Module()
  result.delegate = delegate
  result.events = events
  result.walletAccountService = walletAccountService
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, walletAccountService, networkService, currencyService)
  result.moduleLoaded = false

method delete*(self: Module) =
  self.viewVariant.delete
  self.view.delete
  self.controller.delete

proc getWalletAccounts(self: Module, addresses: seq[string]): seq[wallet_account_service.WalletAccountDto] =
  if addresses.len > 0:
     return self.controller.getWalletAccountsByAddresses(addresses)
  return self.controller.getWalletAccounts()

proc refreshWalletAccountsBalances(self: Module, addresses: seq[string]) =
  let walletAccounts = self.getWalletAccounts(addresses)
  let currency = self.controller.getCurrentCurrency()
  let currencyFormat = self.controller.getCurrencyFormat(currency)
  let marketValuesLoading = self.controller.getTokensMarketValuesLoading()
  for walletAccount in walletAccounts:
    let currencyBalance = self.controller.getTotalCurrencyBalance(walletAccount.address, self.filterChainIds)
    self.view.updateBalance(walletAccount.address, currencyAmountToItem(currencyBalance, currencyFormat), walletAccount.assetsLoading or marketValuesLoading)

proc refreshAllWalletAccountsBalances(self: Module) =
  self.refreshWalletAccountsBalances(@[])

proc getWalletItems(self: Module, addresses: seq[string]): seq[wallet_accounts_item.Item] =
  let walletAccounts = self.getWalletAccounts(addresses)
  let currency = self.controller.getCurrentCurrency()
  let currencyFormat = self.controller.getCurrencyFormat(currency)
  let areTestNetworksEnabled = self.controller.areTestNetworksEnabled()

  return walletAccounts.map(w => (block:
    let currencyBalance = self.controller.getTotalCurrencyBalance(w.address, self.filterChainIds)
    let isKeycardAccount = self.controller.isKeycardAccount(w)
    walletAccountToWalletAccountsItem(
      w,
      isKeycardAccount,
      currencyBalance,
      currencyFormat,
      areTestNetworksEnabled,
      self.controller.getTokensMarketValuesLoading()
    )
  ))

proc updateWalletAccounts(self: Module, addresses: seq[string]) =
  self.view.updateItems(self.getWalletItems(addresses))

method loadAllWalletAccounts*(self: Module) =
  self.view.setItems(self.getWalletItems(@[]))

method filterChanged*(self: Module, chainIds: seq[int]) =
  if self.filterChainIds == chainIds:
    return
  self.filterChainIds = chainIds
  self.refreshAllWalletAccountsBalances()

method load*(self: Module) =
  singletonInstance.setSessionContextProperty("walletSectionAccounts", self.viewVariant)
  self.controller.init()
  self.view.load()

  self.events.on(SIGNAL_TOKENS_MARKET_VALUES_UPDATED) do(e:Args):
    self.refreshAllWalletAccountsBalances()
  self.events.on(SIGNAL_CURRENCY_FORMATS_UPDATED) do(e:Args):
    self.refreshAllWalletAccountsBalances()
  self.events.on(SIGNAL_WALLET_ACCOUNT_TOKENS_REBUILT) do(e:Args):
    self.refreshAllWalletAccountsBalances()
  self.events.on(SIGNAL_WALLET_ACCOUNT_NETWORK_ENABLED_UPDATED) do(e:Args):
    self.refreshAllWalletAccountsBalances()
  self.events.on(SIGNAL_KEYPAIR_SYNCED) do(e: Args):
    self.loadAllWalletAccounts()
  self.events.on(SIGNAL_WALLET_ACCOUNT_UPDATED) do(e:Args):
    let accountArgs = AccountArgs(e)
    self.updateWalletAccounts(@[accountArgs.account.address])
  self.events.on(SIGNAL_WALLET_ACCOUNT_SAVED) do(e:Args):
    let accountArgs = AccountArgs(e)
    self.updateWalletAccounts(@[accountArgs.account.address])
  self.events.on(SIGNAL_WALLET_ACCOUNT_DELETED) do(e:Args):
    let accountArgs = AccountArgs(e)
    self.view.onAccountRemoved(accountArgs.account.address)
  self.events.on(SIGNAL_NEW_KEYCARD_SET) do(e: Args):
    self.loadAllWalletAccounts()
  self.events.on(SIGNAL_ALL_KEYCARDS_DELETED) do(e: Args):
    self.loadAllWalletAccounts()
  self.events.on(SIGNAL_WALLET_ACCOUNT_POSITION_UPDATED) do(e: Args):
    let walletAccounts = self.getWalletAccounts(@[])
    var accountPositions = initTable[string, int]()
    for walletAccount in walletAccounts.items:
      accountPositions[walletAccount.address] = walletAccount.position
    self.view.updateAccountsPositions(accountPositions)
  self.events.on(SIGNAL_WALLET_ACCOUNT_HIDDEN_UPDATED) do(e: Args):
    let accountArgs = AccountArgs(e)
    self.view.updateAccountHiddenFromTotalBalance(accountArgs.account.address, accountArgs.account.hideFromTotalBalance)

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.delegate.accountsModuleDidLoad()

method deleteAccount*(self: Module, address: string, password: string) =
  self.controller.deleteAccount(address, password)

method updateAccount*(self: Module, address: string, accountName: string, colorId: string, emoji: string) =
  self.controller.updateAccount(address, accountName, colorId, emoji)

method updateWatchAccountHiddenFromTotalBalance*(self: Module, address: string, hideFromTotalBalance: bool) =
  self.controller.updateWatchAccountHiddenFromTotalBalance(address, hideFromTotalBalance)

method getWalletAccountAsJson*(self: Module, address: string): JsonNode =
  let walletAccountDto = self.controller.getWalletAccount(address)
  if walletAccountDto.isNil:
    return newJNull()
  return % walletAccountDto
