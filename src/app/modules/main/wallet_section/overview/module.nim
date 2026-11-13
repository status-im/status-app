import nimqml

import app/global/global_singleton
import app/core/eventemitter
import app_service/service/currency/service as currency_service
import app_service/service/wallet_account/service as wallet_account_service
import app/modules/shared/wallet_utils
import app/modules/shared_models/currency_amount
import ./item

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
    isAllAccounts: bool

proc newModule*(
  delegate: delegate_interface.AccessInterface,
  events: EventEmitter,
  walletAccountService: wallet_account_service.Service,
  currencyService: currency_service.Service,
): Module =
  result = Module()
  result.delegate = delegate
  result.events = events
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = newController(result, walletAccountService, currencyService)
  result.moduleLoaded = false
  result.isAllAccounts = false

method delete*(self: Module) =
  self.viewVariant.delete
  self.view.delete

method load*(self: Module) =
  singletonInstance.setSessionContextProperty("walletSectionOverview", self.viewVariant)
  self.controller.init()
  self.view.load()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.view.setCurrencyBalance(newCurrencyAmount())
  self.delegate.overviewModuleDidLoad()

proc setBalance(self: Module, addresses: seq[string], chainIds: seq[int]) =
  let currency = self.controller.getCurrentCurrency()
  let currencyFormat = self.controller.getCurrencyFormat(currency)
  let totalCurrencyBalanceForAllAssets = self.controller.getTotalCurrencyBalance(addresses, chainIds)
  self.view.setCurrencyBalance(currencyAmountToItem(totalCurrencyBalanceForAllAssets, currencyFormat))

proc getWalletAccoutColors(self: Module, walletAccounts: seq[WalletAccountDto]) : seq[string] =
  var colors: seq[string] = @[]
  for account in walletAccounts:
    colors.add(account.colorId)
  return colors

method filterChanged*(self: Module, addresses: seq[string], chainIds: seq[int]) =
  let walletAccounts = self.controller.getWalletAccountsByAddresses(addresses)
  if walletAccounts.len == 0:
    return
  var loading = self.controller.getTokensMarketValuesLoading()
  for account in walletAccounts:
    if account.assetsLoading:
      loading = true
      break 
  if self.isAllAccounts:
    let item = initItem(
      "",
      "",
      "",
      loading,
      "",
      "",
      isWatchOnlyAccount=false,
      isAllAccounts=true,
      self.getWalletAccoutColors(walletAccounts)
    )
    self.view.setData(item)
  else:
    let walletAccount = walletAccounts[0]
    let isWatchOnlyAccount = walletAccount.walletType == "watch"
    let item = initItem(
      walletAccount.name,
      walletAccount.mixedCaseAddress,
      walletAccount.ens,
      loading,
      walletAccount.colorId,
      walletAccount.emoji,
      isWatchOnlyAccount=isWatchOnlyAccount,
      canSend=not isWatchOnlyAccount and (walletAccount.operable==AccountFullyOperable or walletAccount.operable==AccountPartiallyOperable)
    )
    self.view.setData(item)

  if loading:
    self.view.setCurrencyBalance(newCurrencyAmount())
  else:
    self.setBalance(addresses, chainIds)

method setIsAllAccounts(self: Module, value: bool) =
  self.isAllAccounts = value

method getIsAllAccounts(self: Module): bool =
  return self.isAllAccounts
