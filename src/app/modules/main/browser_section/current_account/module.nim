import nimqml, strutils

import app/global/global_singleton
import app/core/eventemitter
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/network/service as network_service
import app_service/service/token/service as token_service
import app_service/service/currency/service as currency_service
import app/modules/shared/wallet_utils

import ./io_interface, ./view, ./controller
import ../io_interface as delegate_interface

export io_interface

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    events: EventEmitter
    view: View
    viewVariant: QVariant
    controller: Controller
    moduleLoaded: bool
    currentAccountIndex: int

proc newModule*(
  delegate: delegate_interface.AccessInterface,
  events: EventEmitter,
  walletAccountService: wallet_account_service.Service,
  networkService: network_service.Service,
  tokenService: token_service.Service,
  currencyService: currency_service.Service,
): Module =
  result = Module()
  result.delegate = delegate
  result.events = events
  result.currentAccountIndex = 0
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = newController(result, walletAccountService, networkService, tokenService, currencyService)
  result.moduleLoaded = false

method delete*(self: Module) =
  self.viewVariant.delete
  self.view.delete

proc switchAccount*(self: Module, accountIndex: int) =
  self.currentAccountIndex = accountIndex

  let walletAccount = self.controller.getWalletAccount(accountIndex)
  if walletAccount.isNil:
    return
  let migratedToColdWallet = self.controller.isKeycardAccount(walletAccount)
  let currency = self.controller.getCurrentCurrency()
  let enabledChainIds = self.controller.getEnabledChainIds()
  let areTestNetworksEnabled = self.controller.areTestNetworksEnabled()
  let currencyFormat = self.controller.getCurrencyFormat(currency)
  let currencyBalance = self.controller.getTotalCurrencyBalance(walletAccount.address, enabledChainIds)

  let accountItem = walletAccountToWalletAccountsItem(
    walletAccount,
    migratedToColdWallet,
    currencyBalance,
    currencyFormat,
    areTestNetworksEnabled,
    self.controller.getTokensMarketValuesLoading()
  )

  self.view.setData(accountItem)

method load*(self: Module) =
  singletonInstance.engine.setRootContextProperty("browserSectionCurrentAccount", self.viewVariant)

  self.events.on(SIGNAL_KEYPAIR_SYNCED) do(e: Args):
    let args = KeypairArgs(e)
    let walletAccount = self.controller.getWalletAccount(self.currentAccountIndex)
    if walletAccount.isNil:
      self.switchAccount(0)
      return
    for acc in args.keypair.accounts:
      if cmpIgnoreCase(acc.address, walletAccount.address) == 0:
        return
    self.switchAccount(0)
    self.view.connectedAccountDeleted()

  self.events.on(SIGNAL_WALLET_ACCOUNT_DELETED) do(e:Args):
    if(self.view.isAddressCurrentAccount(AccountArgs(e).account.address)):
      self.switchAccount(0)
      self.view.connectedAccountDeleted()

  self.controller.init()
  self.view.load()
  self.switchAccount(0)

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true

method switchAccountByAddress*(self: Module, address: string) =
  let accountIndex = self.controller.getIndex(address)
  self.switchAccount(accountIndex)
