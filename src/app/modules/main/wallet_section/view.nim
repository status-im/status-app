import nimqml, json

import ./activity/controller as activityc
import app/modules/shared_modules/collectible_details/controller as collectible_detailsc
import ./io_interface
import app/modules/shared_models/currency_amount
import app/modules/shared_modules/wallet_connect/controller as wc_controller
import app/modules/shared_modules/connector/controller as connector_controller

type
  ActivityControllerArray* = array[2, activityc.Controller]

QtObject:
  type
    View* = ref object of QObject
      delegate: io_interface.AccessInterface
      totalCurrencyBalance: CurrencyAmount
      tmpAmount: float  # shouldn't be used anywhere except in prepare*/getPrepared* procs
      tmpKey: string # shouldn't be used anywhere except in prepare*/getPrepared* procs
      activityController: activityc.Controller
      tmpActivityControllers: ActivityControllerArray
      collectibleDetailsController: collectible_detailsc.Controller
      isNonArchivalNode: bool
      keypairOperabilityForObservedAccount: string
      wcController: QVariant
      dappsConnectorController: QVariant
      walletReady: bool
      addressFilters: string
      currentCurrency: string
      isAccountTokensReloading: bool
      lastReloadTimestamp: int64

  proc setup(self: View)
  proc delete*(self: View)
  proc newView*(delegate: io_interface.AccessInterface,
    activityController: activityc.Controller,
    tmpActivityControllers: ActivityControllerArray,
    collectibleDetailsController: collectible_detailsc.Controller,
    wcController: wc_controller.Controller,
    dappsConnectorController: connector_controller.Controller): View =
    new(result, delete)
    result.delegate = delegate
    result.activityController = activityController
    result.tmpActivityControllers = tmpActivityControllers
    result.collectibleDetailsController = collectibleDetailsController
    if wcController.isNil:
      result.wcController = newQVariant()
    else:
      result.wcController = newQVariant(wcController)
    if dappsConnectorController.isNil:
      result.dappsConnectorController = newQVariant()
    else:
      result.dappsConnectorController = newQVariant(dappsConnectorController)
    result.totalCurrencyBalance = newCurrencyAmount()

    result.setup()

  proc load*(self: View) =
    self.delegate.viewDidLoad()

  proc currentCurrencyChanged*(self: View) {.signal.}
  proc updateCurrency*(self: View, currency: string) {.slot.} =
    self.delegate.updateCurrency(currency)
  proc setCurrentCurrency*(self: View, currency: string) =
    self.currentCurrency = currency
    self.currentCurrencyChanged()
  proc getCurrentCurrency(self: View): string {.slot.} =
    return self.delegate.getCurrentCurrency()
  QtProperty[string] currentCurrency:
    read = getCurrentCurrency
    notify = currentCurrencyChanged

  proc filterChanged*(self: View, addresses: string)  {.signal.}

  proc totalCurrencyBalanceChanged*(self: View) {.signal.}

  proc getTotalCurrencyBalance(self: View): QVariant {.slot.} =
    if self.totalCurrencyBalance.isNil:
      self.totalCurrencyBalance = newCurrencyAmount()
    return newQVariant(self.totalCurrencyBalance)

  QtProperty[QVariant] totalCurrencyBalance:
    read = getTotalCurrencyBalance
    notify = totalCurrencyBalanceChanged

  proc addressFiltersChanged*(self: View) {.signal.}
  proc setAddressFilters*(self: View, address: string) =
    self.addressFilters = address
    self.addressFiltersChanged()
  proc getAddressFilters*(self: View): string {.slot.} =
    return self.addressFilters
  QtProperty[string] addressFilters:
    read = getAddressFilters
    notify = addressFiltersChanged

  proc setFilterAddress(self: View, address: string) {.slot.} =
    self.delegate.setFilterAddress(address)

  proc setFilterAllAddresses*(self: View) {.slot.} =
    self.delegate.setFilterAllAddresses()

  proc setTotalCurrencyBalance*(self: View, totalCurrencyBalance: CurrencyAmount) =
    if totalCurrencyBalance == self.totalCurrencyBalance:
      return
    self.totalCurrencyBalance = totalCurrencyBalance
    self.totalCurrencyBalanceChanged()

  proc getCurrencyAmount*(self: View, amount: float, key: string): string {.slot.} =
    let currencyAmount = self.delegate.getCurrencyAmount(amount, key)
    return $(currencyAmount.toJsonNode())

  proc runAddAccountPopup*(self: View, addingWatchOnlyAccount: bool) {.slot.} =
    self.delegate.runAddAccountPopup(addingWatchOnlyAccount)

  proc runEditAccountPopup*(self: View, address: string) {.slot.} =
    self.delegate.runEditAccountPopup(address)

  proc getAddAccountModule(self: View): QVariant {.slot.} =
    return self.delegate.getAddAccountModule()
  QtProperty[QVariant] addAccountModule:
    read = getAddAccountModule

  proc displayAddAccountPopup*(self: View) {.signal.}
  proc emitDisplayAddAccountPopup*(self: View) =
    self.displayAddAccountPopup()

  proc destroyAddAccountPopup*(self: View) {.signal.}
  proc emitDestroyAddAccountPopup*(self: View) =
    self.destroyAddAccountPopup()

  proc walletAccountRemoved*(self: View, address: string) {.signal.}
  proc emitWalletAccountRemoved*(self: View, address: string) =
    self.walletAccountRemoved(address)

  proc getActivityController(self: View): QVariant {.slot.} =
    if self.activityController.isNil:
      return newQVariant()
    return newQVariant(self.activityController)
  QtProperty[QVariant] activityController:
    read = getActivityController

  proc getCollectibleDetailsController(self: View): QVariant {.slot.} =
    if self.collectibleDetailsController.isNil:
      return newQVariant()
    return newQVariant(self.collectibleDetailsController)
  QtProperty[QVariant] collectibleDetailsController:
    read = getCollectibleDetailsController

  proc getTmpActivityController0(self: View): QVariant {.slot.} =
    if self.tmpActivityControllers[0].isNil:
      return newQVariant()
    return newQVariant(self.tmpActivityControllers[0])
  QtProperty[QVariant] tmpActivityController0:
    read = getTmpActivityController0

  proc getTmpActivityController1(self: View): QVariant {.slot.} =
    if self.tmpActivityControllers[1].isNil:
      return newQVariant()
    return newQVariant(self.tmpActivityControllers[1])
  QtProperty[QVariant] tmpActivityController1:
    read = getTmpActivityController1

  proc fetchDecodedTxData*(self: View, txHash: string, data: string) {.slot.}   =
    self.delegate.fetchDecodedTxData(txHash, data)

  proc getIsNonArchivalNode(self: View): bool {.slot.} =
    return self.isNonArchivalNode

  proc isNonArchivalNodeChanged(self: View) {.signal.}

  proc setIsNonArchivalNode*(self: View, isNonArchivalNode: bool) =
    self.isNonArchivalNode = isNonArchivalNode
    self.isNonArchivalNodeChanged()

  QtProperty[bool] isNonArchivalNode:
    read = getIsNonArchivalNode
    notify = isNonArchivalNodeChanged

  proc txDecoded*(self: View, txHash: string, dataDecoded: string) {.signal.}

  proc hasPairedDevicesChanged*(self: View) {.signal.}
  proc emitHasPairedDevicesChangedSignal*(self: View) =
    self.hasPairedDevicesChanged()
  proc getHasPairedDevices(self: View): bool {.slot.} =
    return self.delegate.hasPairedDevices()
  QtProperty[bool] hasPairedDevices:
    read = getHasPairedDevices
    notify = hasPairedDevicesChanged

  proc keypairOperabilityForObservedAccountChanged(self: View) {.signal.}
  proc getKeypairOperabilityForObservedAccount(self: View): string {.slot.} =
    return self.keypairOperabilityForObservedAccount
  QtProperty[string] keypairOperabilityForObservedAccount:
    read = getKeypairOperabilityForObservedAccount
    notify = keypairOperabilityForObservedAccountChanged
  proc setKeypairOperabilityForObservedAccount*(self: View, value: string) =
    self.keypairOperabilityForObservedAccount = value
    self.keypairOperabilityForObservedAccountChanged()

  proc runKeypairImportPopup*(self: View) {.slot.} =
    self.delegate.runKeypairImportPopup()

  proc keypairImportModuleChanged*(self: View) {.signal.}
  proc emitKeypairImportModuleChangedSignal*(self: View) =
    self.keypairImportModuleChanged()
  proc getKeypairImportModule(self: View): QVariant {.slot.} =
    return self.delegate.getKeypairImportModule()
  QtProperty[QVariant] keypairImportModule:
    read = getKeypairImportModule
    notify = keypairImportModuleChanged

  proc displayKeypairImportPopup*(self: View) {.signal.}
  proc emitDisplayKeypairImportPopup*(self: View) =
    self.displayKeypairImportPopup()

  proc destroyKeypairImportPopup*(self: View) {.signal.}
  proc emitDestroyKeypairImportPopup*(self: View) =
    self.destroyKeypairImportPopup()

  proc getWalletConnectController(self: View): QVariant {.slot.} =
    if self.wcController == nil:
      return newQVariant()
    return self.wcController

  QtProperty[QVariant] walletConnectController:
    read = getWalletConnectController

  proc getDappsConnectorController(self: View): QVariant {.slot.} =
    if self.dappsConnectorController == nil:
      return newQVariant()
    return self.dappsConnectorController

  QtProperty[QVariant] dappsConnectorController:
    read = getDappsConnectorController

  proc walletReadyChanged*(self: View) {.signal.}

  proc getWalletReady*(self: View): bool {.slot.} =
    return self.walletReady

  proc setWalletReady*(self: View) =
    if not self.walletReady:
      self.walletReady = true
      self.walletReadyChanged()

  QtProperty[bool] walletReady:
    read = getWalletReady
    notify = walletReadyChanged

  proc getRpcStats*(self: View): string {.slot.} =
    return self.delegate.getRpcStats()
  proc resetRpcStats*(self: View) {.slot.} =
    self.delegate.resetRpcStats()

  proc canProfileProveOwnershipOfProvidedAddresses*(self: View, addresses: string): bool {.slot.} =
    return self.delegate.canProfileProveOwnershipOfProvidedAddresses(addresses)

  proc reloadAccountTokens*(self: View) {.slot.} =
    self.delegate.reloadAccountTokens()

  proc lastReloadTimestampChanged*(self: View) {.signal.}

  proc setLastReloadTimestamp*(self: View, lastReloadTimestamp: int64) =
    if lastReloadTimestamp == self.lastReloadTimestamp:
      return
    self.lastReloadTimestamp = lastReloadTimestamp
    self.lastReloadTimestampChanged()

  proc getLastReloadTimestamp(self: View): QVariant {.slot.} =
    return newQVariant(self.lastReloadTimestamp)

  QtProperty[QVariant] lastReloadTimestamp:
    read = getLastReloadTimestamp
    notify = lastReloadTimestampChanged

  proc isAccountTokensReloadingChanged*(self: View) {.signal.}

  proc setIsAccountTokensReloading*(self: View, isAccountTokensReloading: bool) =
    if isAccountTokensReloading == self.isAccountTokensReloading:
      return
    self.isAccountTokensReloading = isAccountTokensReloading
    self.isAccountTokensReloadingChanged()

  proc getIsAccountTokensReloading(self: View): bool {.slot.} =
    return self.isAccountTokensReloading

  QtProperty[bool] isAccountTokensReloading:
    read = getIsAccountTokensReloading
    notify = isAccountTokensReloadingChanged

  proc isChecksumValidForAddress*(self: View, address: string): bool {.slot.} =
    return self.delegate.isChecksumValidForAddress(address)

  proc setup(self: View) =
    self.QObject.setup

  proc delete*(self: View) =
    self.QObject.delete

