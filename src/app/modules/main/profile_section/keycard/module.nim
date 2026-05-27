import nimqml, chronicles, sequtils, sugar, strutils

import ./io_interface, ./view, ./controller
import ../io_interface as delegate_interface

import app/global/app_translatable_constants as atc
import app/global/global_singleton
import app/core/eventemitter

import app_service/service/keycard/service as keycard_service
import app_service/service/settings/service as settings_service
import app_service/service/network/service as network_service
import app_service/service/privacy/service as privacy_service
import app_service/service/accounts/service as accounts_service
import app_service/service/wallet_account/service as wallet_account_service

import app/modules/shared_modules/keycard_popup/module as keycard_shared_module
import app/modules/shared_modules/keycard_popup/models/keycard_model

export io_interface

logScope:
  topics = "profile-section-profile-module"

type
  Module* = ref object of io_interface.AccessInterface
    delegate: delegate_interface.AccessInterface
    controller: Controller
    view: View
    viewVariant: QVariant
    moduleLoaded: bool
    events: EventEmitter
    keycardService: keycard_service.Service
    settingsService: settings_service.Service
    networkService: network_service.Service
    privacyService: privacy_service.Service
    accountsService: accounts_service.Service
    walletAccountService: wallet_account_service.Service
    keycardSharedModule: keycard_shared_module.AccessInterface

## Forward declarations
proc buildKeycardList(self: Module)

proc newModule*(delegate: delegate_interface.AccessInterface,
  events: EventEmitter,
  keycardService: keycard_service.Service,
  settingsService: settings_service.Service,
  networkService: network_service.Service,
  privacyService: privacy_service.Service,
  accountsService: accounts_service.Service,
  walletAccountService: wallet_account_service.Service
  ): Module =
  result = Module()
  result.delegate = delegate
  result.events = events
  result.keycardService = keycardService
  result.settingsService = settingsService
  result.networkService = networkService
  result.privacyService = privacyService
  result.accountsService = accountsService
  result.walletAccountService = walletAccountService
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, events, walletAccountService)
  result.moduleLoaded = false

method delete*(self: Module) =
  self.view.delete
  self.viewVariant.delete
  self.controller.delete
  if not self.keycardSharedModule.isNil:
    self.keycardSharedModule.delete

method load*(self: Module) =
  self.controller.init()
  self.view.load()
  self.buildKeycardList()

method isLoaded*(self: Module): bool =
  return self.moduleLoaded

method viewDidLoad*(self: Module) =
  self.moduleLoaded = true
  self.delegate.profileModuleDidLoad()

method getModuleAsVariant*(self: Module): QVariant =
  return self.viewVariant

proc isSharedKeycardModuleFlowRunning(self: Module): bool =
  return not self.keycardSharedModule.isNil

method getKeycardSharedModule*(self: Module): QVariant =
  if self.isSharedKeycardModuleFlowRunning():
    return self.keycardSharedModule.getModuleAsVariant()

proc createSharedKeycardModule(self: Module) =
  if self.isSharedKeycardModuleFlowRunning():
    info "keycard shared module is still running"
    self.view.emitSharedModuleBusy()
    return
  self.keycardSharedModule = keycard_shared_module.newModule[Module](self, UNIQUE_SETTING_KEYCARD_MODULE_IDENTIFIER,
    self.events, self.keycardService, self.settingsService, self.networkService, self.privacyService, self.accountsService,
    self.walletAccountService)

method onSharedKeycarModuleFlowTerminated*(self: Module, lastStepInTheCurrentFlow: bool, nextFlow: keycard_shared_module.FlowType,
  forceFlow: bool, nextKeyUid: string, returnToFlow: keycard_shared_module.FlowType) =
  if self.isSharedKeycardModuleFlowRunning():
    if nextFlow == keycard_shared_module.FlowType.General:
      self.view.emitDestroyKeycardSharedModuleFlow()
      self.keycardSharedModule.delete
      self.keycardSharedModule = nil
      return
    self.keycardSharedModule.runFlow(nextFlow, nextKeyUid, bip44Paths = @[], txHash = "", forceFlow, returnToFlow)

method onDisplayKeycardSharedModuleFlow*(self: Module) =
  self.view.emitDisplayKeycardSharedModuleFlow()

method runSetupKeycardPopup*(self: Module, keyUid: string) =
  self.createSharedKeycardModule()
  if self.keycardSharedModule.isNil:
    return
  self.keycardSharedModule.runFlow(keycard_shared_module.FlowType.SetupNewKeycard, keyUid)

method runStopUsingKeycardPopup*(self: Module, keyUid: string) =
  self.createSharedKeycardModule()
  if self.keycardSharedModule.isNil:
    return
  self.keycardSharedModule.runFlow(keycard_shared_module.FlowType.MigrateFromKeycardToApp, keyUid)

method runCreateNewKeycardWithNewSeedPhrasePopup*(self: Module) =
  self.createSharedKeycardModule()
  if self.keycardSharedModule.isNil:
    return
  self.keycardSharedModule.runFlow(keycard_shared_module.FlowType.SetupNewKeycardNewSeedPhrase)

method runImportOrRestoreViaSeedPhrasePopup*(self: Module) =
  self.createSharedKeycardModule()
  if self.keycardSharedModule.isNil:
    return
  self.keycardSharedModule.runFlow(keycard_shared_module.FlowType.SetupNewKeycardOldSeedPhrase)

method runImportFromKeycardToAppPopup*(self: Module) =
  self.createSharedKeycardModule()
  if self.keycardSharedModule.isNil:
    return
  self.keycardSharedModule.runFlow(keycard_shared_module.FlowType.ImportFromKeycard)

method runUnlockKeycardPopupForKeycardWithUid*(self: Module, keyUid: string) =
  self.createSharedKeycardModule()
  if self.keycardSharedModule.isNil:
    return
  self.keycardSharedModule.runFlow(keycard_shared_module.FlowType.UnlockKeycard, keyUid)

method runDisplayKeycardContentPopup*(self: Module) =
  self.createSharedKeycardModule()
  if self.keycardSharedModule.isNil:
    return
  self.keycardSharedModule.runFlow(keycard_shared_module.FlowType.DisplayKeycardContent)

method runFactoryResetPopup*(self: Module) =
  self.createSharedKeycardModule()
  if self.keycardSharedModule.isNil:
    return
  self.keycardSharedModule.runFlow(keycard_shared_module.FlowType.FactoryReset)

method runRenameKeycardPopup*(self: Module, keyUid: string) =
  self.createSharedKeycardModule()
  if self.keycardSharedModule.isNil:
    return
  self.keycardSharedModule.runFlow(keycard_shared_module.FlowType.RenameKeycard, keyUid)

method runChangePinPopup*(self: Module, keyUid: string) =
  self.createSharedKeycardModule()
  if self.keycardSharedModule.isNil:
    return
  self.keycardSharedModule.runFlow(keycard_shared_module.FlowType.ChangeKeycardPin, keyUid)

method runCreateBackupCopyOfAKeycardPopup*(self: Module, keyUid: string) =
  self.createSharedKeycardModule()
  if self.keycardSharedModule.isNil:
    return
  self.keycardSharedModule.runFlow(keycard_shared_module.FlowType.CreateCopyOfAKeycard, keyUid)

method runCreatePukPopup*(self: Module, keyUid: string) =
  self.createSharedKeycardModule()
  if self.keycardSharedModule.isNil:
    return
  self.keycardSharedModule.runFlow(keycard_shared_module.FlowType.ChangeKeycardPuk, keyUid)

method runCreateNewPairingCodePopup*(self: Module, keyUid: string) =
  self.createSharedKeycardModule()
  if self.keycardSharedModule.isNil:
    return
  self.keycardSharedModule.runFlow(keycard_shared_module.FlowType.ChangePairingCode, keyUid)

proc findAccountByAccountAddress(accounts: seq[WalletAccountDto], address: string): WalletAccountDto =
  for acc in accounts:
    if cmpIgnoreCase(acc.address, address) == 0:
      return acc
  return nil

proc addAccountsToKeycardItem(self: Module, item: KeycardItem, accounts: seq[WalletAccountDto]) =
  if accounts.len == 0:
    return
  var accType = accounts[0].walletType
  if accType == WalletTypeGenerated:
    item.setPairType(KeyPairType.Profile.int)
    item.setPubKey(singletonInstance.userProfile.getPubKey())
    item.setImage(singletonInstance.userProfile.getIcon())
  if accType == WalletTypeSeed:
    item.setPairType(KeyPairType.SeedImport.int)
    item.setIcon("keycard")
  if accType == WalletTypeKey:
    item.setPairType(KeyPairType.PrivateKeyImport.int)
    item.setIcon("keycard")
  for acc in accounts:
    if acc.isChat:
      continue
    var icon = ""
    if acc.emoji.len == 0:
      icon = "wallet"
    item.addAccount(newKeyPairAccountItem(acc.name, acc.path, acc.address, acc.publicKey, acc.emoji, acc.colorId,
      icon = icon))

proc buildMainViewKeycardItem(self: Module, keypair: KeypairDto): KeycardItem =
  if keypair.isNil or not keypair.migratedToColdWallet():
    return
  var item = initKeycardItem(keycardUid = "",
    keyUid = keypair.keyUid,
    pubKey = "",
    locked = false,
    name = keypair.name)
  ## If all created keycards for certain keypair are locked, then we need to display that item as locked.
  item.setLocked(keypair.keycards.all(kp => kp.keycardLocked))
  self.addAccountsToKeycardItem(item, keypair.accounts)
  return item

proc buildDetailsViewKeycardItem(self: Module, keycard: KeycardDto): KeycardItem =
  let isAccountInKnownAccounts = proc(knownAccounts: seq[WalletAccountDto], address: string): bool =
    for i in 0 ..< knownAccounts.len:
      if cmpIgnoreCase(knownAccounts[i].address, address) == 0:
        return true
    return false

  if keycard.keyUid.len == 0:
    return
  let keypair = self.controller.getKeypairByKeyUid(keycard.keyUid)
  if keypair.isNil:
    return

  var knownAccounts: seq[WalletAccountDto]
  var unknownAccountsAddresses: seq[string]
  for accAddr in keycard.accountsAddresses:
    let account = findAccountByAccountAddress(keypair.accounts, accAddr)
    if account.isNil:
      ## We are here if the keycard is not synced yet with the app's state. That may happen if there are more copies of the
      ## same keycard, then deleting an account for a keypair syncs the inserted keycard, but other copies of the card
      ## remain with that account till the moment they are synced.
      unknownAccountsAddresses.add(accAddr)
      continue
    knownAccounts.add(account)
  var item = initKeycardItem(keycardUid = keycard.keycardUid,
    keyUid = keycard.keyUid,
    pubKey = "",
    locked = keycard.keycardLocked,
    name = keycard.keycardName)
  if knownAccounts.len == 0:
    item.setPairType(KeyPairType.SeedImport.int)
    item.setIcon("keycard")
  else:
    item.setDerivedFrom(keypair.derivedFrom)

  # add known accounts
  self.addAccountsToKeycardItem(item, knownAccounts)

  # add unknown accounts
  var i = 0
  for ua in unknownAccountsAddresses:
    i.inc
    let name = atc.KEYCARD_ACCOUNT_NAME_OF_UNKNOWN_WALLET_ACCOUNT & $i
    item.addAccount(newKeyPairAccountItem(name, path = "", ua, pubKey = "", emoji = "", colorId = "undefined", icon = "wallet"))
  return item

proc buildKeycardList(self: Module) =
  var items: seq[KeycardItem]
  let keypairs = self.controller.getKeypairs()
  for kp in keypairs:
    let item = self.buildMainViewKeycardItem(kp)
    if item.isNil:
      continue
    items.add(item)
  if items.len > 0:
    self.view.setKeycardItems(items)

method onLoggedInUserNameChanged*(self: Module) =
  self.view.keycardModel().setName(singletonInstance.userProfile.getKeyUid(), singletonInstance.userProfile.getName())

method onLoggedInUserImageChanged*(self: Module) =
  self.view.keycardModel().setImage(singletonInstance.userProfile.getKeyUid(), singletonInstance.userProfile.getIcon())
  if self.view.keycardDetailsModel().isNil:
    return
  self.view.keycardDetailsModel().setImage(singletonInstance.userProfile.getKeyUid(), singletonInstance.userProfile.getIcon())

proc resolveRelatedKeycardsForKeypair(self: Module, keypair: KeypairDto) =
  if keypair.keyUid.len == 0:
    error "cannot rebuild keycards for a keypair with empty keyUid"
    return

  let
    thereAreDisplayedKeycardsForKeypair = not self.view.keycardModel().getItemForKeyUid(keypair.keyUid).isNil
    detailsViewCurrentlyDisplayed = not self.view.keycardDetailsModel().isNil

  # create main view item
  let mainViewItem = self.buildMainViewKeycardItem(keypair)

  # prepare main view item and if needed details view item
  var detailsViewItems: seq[KeycardItem]
  for kc in keypair.keycards:
    let item = self.buildDetailsViewKeycardItem(kc)
    if not item.isNil:
      detailsViewItems.add(item)

  if thereAreDisplayedKeycardsForKeypair:
    if not keypair.migratedToColdWallet():
      # remove all related keycards from the app
      self.view.keycardModel().removeItemsWithKeyUid(keypair.keyUid)
      if not detailsViewCurrentlyDisplayed:
        return
      self.view.keycardDetailsModel().removeItemsWithKeyUid(keypair.keyUid)
      return
    if keypair.migratedToColdWallet():
      # replace displayed keycards
      if not mainViewItem.isNil:
        self.view.keycardModel().replaceItemWithKeyUid(mainViewItem)
      if not detailsViewCurrentlyDisplayed:
        return
      self.view.keycardDetailsModel().setItems(detailsViewItems)
      return
    return
  # display new keycards
  if not mainViewItem.isNil:
    self.view.keycardModel().addItem(mainViewItem)
  if not detailsViewCurrentlyDisplayed:
    return
  self.view.keycardDetailsModel().setItems(detailsViewItems)

method rebuildAllKeycards*(self: Module) =
  # We don't need to take care about details model here, cause since this is called only when account
  # reordering occurs it's impossible to have details keycard view displayed.
  self.buildKeycardList()

method onKeypairSynced*(self: Module, keypair: KeypairDto) =
  self.resolveRelatedKeycardsForKeypair(keypair)

method onKeycardChange*(self: Module, keycard: KeycardDto) =
  assert keycard.keyUid.len > 0, "cannot proceed with keycard with an empty keyUid"
  let keypair = self.controller.getKeypairByKeyUid(keycard.keyUid)
  if keypair.isNil:
    return
  self.resolveRelatedKeycardsForKeypair(keypair)

method onWalletAccountChange*(self: Module, account: WalletAccountDto) =
  if account.isNil or account.keyUid.len == 0:
    return
  let keypair = self.controller.getKeypairByKeyUid(account.keyUid)
  if not keypair.isNil:
    self.resolveRelatedKeycardsForKeypair(keypair)
    return
  # we should be here if the last account for a keypair was deleted
  if self.view.keycardModel().getItemForKeyUid(account.keyUid).isNil:
    return
  self.view.keycardModel().removeItemsWithKeyUid(account.keyUid)
  if self.view.keycardDetailsModel().isNil:
    return
  self.view.keycardDetailsModel().removeItemsWithKeyUid(account.keyUid)

method onKeycardLocked*(self: Module, keyUid: string, keycardUid: string) =
  assert keyUid.len > 0, "cannot proceed with keycard with an empty keyUid"
  assert keycardUid.len > 0, "cannot proceed with keycard with an empty keycardUid"
  let keypair = self.controller.getKeypairByKeyUid(keyUid)
  if keypair.isNil:
    return
  if keypair.keycards.all(kp => kp.keycardLocked):
    self.view.keycardModel().setLockedForKeycardsWithKeyUid(keyUid, true)
  if self.view.keycardDetailsModel().isNil:
    return
  self.view.keycardDetailsModel().setLockedForKeycardWithKeycardUid(keycardUid, true)

method onKeycardUnlocked*(self: Module, keyUid: string, keycardUid: string) =
  self.view.keycardModel().setLockedForKeycardsWithKeyUid(keyUid, false)
  if self.view.keycardDetailsModel().isNil:
    return
  self.view.keycardDetailsModel().setLockedForKeycardWithKeycardUid(keycardUid, false)

method onKeycardNameChanged*(self: Module, keycardUid: string, keycardNewName: string) =
  # keycard on the main view should always follow corresponding keypair
  if self.view.keycardDetailsModel().isNil:
    return
  self.view.keycardDetailsModel().setNameForKeycardWithKeycardUid(keycardUid, keycardNewName)

method onKeycardUidUpdated*(self: Module, keycardUid: string, keycardNewUid: string) =
  if self.view.keycardDetailsModel().isNil:
    return
  self.view.keycardDetailsModel().setKeycardUid(keycardUid, keycardNewUid)

method prepareKeycardDetailsModel*(self: Module, keyUid: string) =
  var items: seq[KeycardItem]
  let keycards = self.controller.getKeycardsWithSameKeyUid(keyUid)
  for kc in keycards:
    let item = self.buildDetailsViewKeycardItem(kc)
    if item.isNil:
      continue
    items.add(item)
  self.view.createModelAndSetKeycardDetailsItems(items)

method remainingKeypairCapacity*(self: Module): int =
  return self.controller.remainingKeypairCapacity()

method remainingAccountCapacity*(self: Module): int =
  return self.controller.remainingAccountCapacity()
