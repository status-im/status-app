import nimqml, tables, strutils, sequtils, chronicles

import io_interface
import view, controller
import internal/[state, state_factory]

import app/core/eventemitter

import app/global/global_singleton

import app/modules/shared/keypairs
import app/modules/shared_models/[keypair_model, derived_address_model]

import app_service/common/account_constants
const dummyUsage = account_constants.ZERO_ADDRESS # dummy usage to prevent false-alarm warning

import app_service/service/accounts/service as accounts_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/saved_address/service as saved_address_service

export io_interface

const Label_NewWatchOnlyAccount = "LABEL-NEW-WATCH-ONLY-ACCOUNT"
const Label_WatchOnlyAccount = "LABEL-WATCH-ONLY-ACCOUNT"
const Label_Existing = "LABEL-EXISTING"
const Label_ImportNew = "LABEL-IMPORT-NEW"
const Label_OptionAddNewMasterKey = "LABEL-OPTION-ADD-NEW-MASTER-KEY"
const Label_OptionAddWatchOnlyAcc = "LABEL-OPTION-ADD-WATCH-ONLY-ACC"


logScope:
  topics = "wallet-add-account-module"

type
  AuthenticationReason {.pure.} = enum
    AddingAccount = 0
    EditingDerivationPath

type
  Module*[T: io_interface.DelegateInterface] = ref object of io_interface.AccessInterface
    delegate: T
    events: EventEmitter
    view: View
    viewVariant: QVariant
    controller: Controller
    authenticationReason: AuthenticationReason
    fetchingAddressesIsInProgress: bool

## Forward declaration
proc doAddAccount[T](self: Module[T])

proc newModule*[T](delegate: T,
  events: EventEmitter,
  accountsService: accounts_service.Service,
  walletAccountService: wallet_account_service.Service,
  savedAddressService: saved_address_service.Service):
  Module[T] =
  result = Module[T]()
  result.delegate = delegate
  result.events = events
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, events, accountsService, walletAccountService,
    savedAddressService)
  result.authenticationReason = AuthenticationReason.AddingAccount
  result.fetchingAddressesIsInProgress = false

{.push warning[Deprecated]: off.}

method delete*[T](self: Module[T]) =
  self.view.delete
  self.viewVariant.delete
  self.controller.delete

method loadForAddingAccount*[T](self: Module[T], addingWatchOnlyAccount: bool) =
  self.controller.init()
  self.view.setEditMode(false)
  self.view.setCurrentState(newMainState(nil))

  var items = keypairs.buildKeyPairsList(self.controller.getKeypairs(), excludeAlreadyMigratedPairs = false,
    excludePrivateKeyKeypairs = true)
  if items.len == 0:
    error "list of identified keypairs is empty, but it must have at least a profile keypair"
    return
  if items.len > 1:
    var item = newKeyPairItem(keyUid = Label_Existing)
    items.insert(item, 1)
  var item = newKeyPairItem(keyUid = Label_ImportNew)
  items.add(item)
  item = newKeyPairItem(keyUid = Label_OptionAddNewMasterKey)
  item.setIcon("objects")
  items.add(item)
  item = newKeyPairItem(keyUid = Label_OptionAddWatchOnlyAcc)
  item.setName(Label_NewWatchOnlyAccount)
  item.setIcon("show")
  items.add(item)

  self.view.setDisablePopup(false)
  self.view.setOriginModelItems(items)
  if addingWatchOnlyAccount:
    self.changeSelectedOrigin(Label_OptionAddWatchOnlyAcc)
  else:
    self.changeSelectedOrigin(items[0].getKeyUid())
  self.delegate.onAddAccountModuleLoaded()

method loadForEditingAccount*[T](self: Module[T], address: string) =
  self.controller.init()
  self.view.setEditMode(true)
  self.view.setCurrentState(newMainState(nil))

  let accountDto = self.controller.getWalletAccount(address)
  var addressDetailsItem = newDerivedAddressItem(order = 0,
    address = accountDto.address,
    publicKey = accountDto.publicKey,
    path = accountDto.path,
    alreadyCreated = true,
    hasActivity = false,
    alreadyCreatedChecked = true,
    detailsLoaded = true)

  self.view.setDisablePopup(false)
  self.view.setStoredAccountName(accountDto.name)
  self.view.setStoredSelectedColorId(accountDto.colorId)
  self.view.setStoredSelectedEmoji(accountDto.emoji)
  self.view.setAccountName(accountDto.name)
  self.view.setSelectedColorId(accountDto.colorId)
  self.view.setSelectedEmoji(accountDto.emoji)

  if accountDto.walletType == WalletTypeWatch:
    var item = newKeyPairItem(keyUid = Label_OptionAddWatchOnlyAcc)
    item.setName(Label_WatchOnlyAccount)
    item.setIcon("show")
    self.view.setSelectedOrigin(item)
    self.view.setWatchOnlyAccAddress(addressDetailsItem)
  else:
    var items = keypairs.buildKeyPairsList(self.controller.getKeypairs(), excludeAlreadyMigratedPairs = false,
      excludePrivateKeyKeypairs = false)
    if items.len == 0:
      error "list of identified keypairs is empty, but it must have at least a profile keypair"
      return

    var selectedOrigin: KeyPairItem
    for item in items:
      if item.containsAccountAddress(address):
        selectedOrigin = item
        break

    if selectedOrigin.isNil or selectedOrigin.getKeyUid().len == 0:
      error "selected address for editing is not known among identified keypairs", address=address
      return

    if selectedOrigin.getPairType() == KeyPairType.Profile.int or
      selectedOrigin.getPairType() == KeyPairType.SeedImport.int:
        self.view.setSelectedDerivedAddress(addressDetailsItem)
    elif selectedOrigin.getPairType() == KeyPairType.PrivateKeyImport.int:
      self.view.setPrivateKeyAccAddress(addressDetailsItem)

    self.view.setOriginModelItems(items)
    self.view.setDerivationPath(accountDto.path)
    self.view.setSelectedOrigin(selectedOrigin)

  self.delegate.onAddAccountModuleLoaded()

proc tryKeycardSync[T](self: Module[T]) =
  discard

method closeAddAccountPopup*[T](self: Module[T]) =
  if not self.view.getEditMode():
    self.tryKeycardSync()
  self.delegate.destroyAddAccountPopup()

method getModuleAsVariant*[T](self: Module[T]): QVariant =
  return self.viewVariant

method getSeedPhrase*[T](self: Module[T]): string =
  return self.controller.getSeedPhrase()

method onBackActionClicked*[T](self: Module[T]) =
  let currStateObj = self.view.currentStateObj()
  if currStateObj.isNil:
    error "waa_cannot resolve current state"
    return
  debug "waa_back_action", currState=currStateObj.stateType()
  currStateObj.executePreBackStateCommand(self.controller)
  let backState = currStateObj.getBackState()
  if backState.isNil:
    return
  self.view.setCurrentState(backState)
  debug "waa_back_action - set state", newCurrState=backState.stateType()

method onCancelActionClicked*[T](self: Module[T]) =
  let currStateObj = self.view.currentStateObj()
  if currStateObj.isNil:
    error "waa_cannot resolve current state"
    return
  debug "waa_cancel_action", currState=currStateObj.stateType()
  currStateObj.executeCancelCommand(self.controller)

method onPrimaryActionClicked*[T](self: Module[T]) =
  let currStateObj = self.view.currentStateObj()
  if currStateObj.isNil:
    error "waa_cannot resolve current state"
    return
  debug "waa_primary_action", currState=currStateObj.stateType()
  currStateObj.executePrePrimaryStateCommand(self.controller)
  let nextState = currStateObj.getNextPrimaryState(self.controller)
  if nextState.isNil:
    return
  self.view.setCurrentState(nextState)
  debug "waa_primary_action - set state", setCurrState=nextState.stateType()

method onSecondaryActionClicked*[T](self: Module[T]) =
  let currStateObj = self.view.currentStateObj()
  if currStateObj.isNil:
    error "waa_cannot resolve current state"
    return
  debug "waa_secondary_action", currState=currStateObj.stateType()
  currStateObj.executePreSecondaryStateCommand(self.controller)
  let nextState = currStateObj.getNextSecondaryState(self.controller)
  if nextState.isNil:
    return
  self.view.setCurrentState(nextState)
  debug "waa_secondary_action - set state", setCurrState=nextState.stateType()

method onTertiaryActionClicked*[T](self: Module[T]) =
  let currStateObj = self.view.currentStateObj()
  if currStateObj.isNil:
    error "waa_cannot resolve current state"
    return
  debug "waa_tertiary_action", currState=currStateObj.stateType()
  currStateObj.executePreTertiaryStateCommand(self.controller)
  let nextState = currStateObj.getNextTertiaryState(self.controller)
  if nextState.isNil:
    return
  self.view.setCurrentState(nextState)
  debug "waa_tertiarry_action - set state", setCurrState=nextState.stateType()

method onQuaternaryActionClicked*[T](self: Module[T]) =
  let currStateObj = self.view.currentStateObj()
  if currStateObj.isNil:
    error "waa_cannot resolve current state"
    return
  debug "waa_quaternary_action", currState=currStateObj.stateType()
  currStateObj.executePreQuaternaryStateCommand(self.controller)
  let nextState = currStateObj.getNextQuaternaryState(self.controller)
  if nextState.isNil:
    return
  self.view.setCurrentState(nextState)
  debug "waa_quaternary_action - set state", setCurrState=nextState.stateType()

proc isKeyPairAlreadyAdded[T](self: Module[T], keyUid: string): bool =
  let keypair = self.controller.getKeypairByKeyUid(keyUid)
  return not keypair.isNil

proc getNumOfAddressesToGenerate[T](self: Module[T]): int =
  let selectedOrigin = self.view.getSelectedOrigin()
  return self.controller.getNumOfAddressesToGenerateForKeypair(selectedOrigin.getKeyUid())

proc fetchDerivedAddressesFromColdWalletKeypair[T](self: Module[T], keyUid: string, paths: seq[string]) =
  let keypair = self.controller.getKeypairByKeyUid(keyUid)
  if keypair.isNil or keypair.extendedPublicKey.len == 0:
    self.onDerivedAddressesFetched(@[], "cannot resolve the extended public key for the selected keypair")
    return
  var relativePaths: seq[string]
  for p in paths:
    if p.startsWith(PATH_WALLET_XPUB & "/"):
      relativePaths.add(p.replace(PATH_WALLET_XPUB & "/", ""))
  let derived = self.controller.deriveAccountsPublicInfoFromExtendedPublicKeyForPaths(keypair.extendedPublicKey, relativePaths)
  var derivedAddresses: seq[DerivedAddressDto]
  for p in paths:
    let relativePath = p.replace(PATH_WALLET_XPUB & "/", "")
    if derived.derivations.hasKey(relativePath):
      let acc = derived.derivations[relativePath]
      derivedAddresses.add(DerivedAddressDto(
        address: acc.address,
        publicKey: acc.publicKey,
        path: p,
        hasActivity: false,
        alreadyCreated: false))
  self.onDerivedAddressesFetched(derivedAddresses, "")

proc fetchAddressForDerivationPath[T](self: Module[T]) =
  let derivationPath = self.view.getDerivationPath()
  let derivedAddress = self.view.getSelectedDerivedAddress()
  if derivationPath == derivedAddress.getPath() and derivedAddress.getAddress().len > 0:
    return
  if self.fetchingAddressesIsInProgress:
    return
  self.fetchingAddressesIsInProgress = true
  self.view.setScanningForActivityIsOngoing(false)
  self.view.derivedAddressModel().reset()
  self.view.setSelectedDerivedAddress(newDerivedAddressItem())

  let selectedOrigin = self.view.getSelectedOrigin()
  var paths: seq[string]
  if derivationPath.endsWith("/"):
    for i in 0 ..< self.getNumOfAddressesToGenerate():
      let path = derivationPath & $i
      # exclude paths for which user already has created accounts
      if selectedOrigin.containsAccountPath(path):
        continue
      paths.add(path)
  else:
    paths.add(derivationPath)

  if selectedOrigin.getPairType() == KeyPairType.Profile.int or
    selectedOrigin.getPairType() == KeyPairType.SeedImport.int:
      if not self.isKeyPairAlreadyAdded(selectedOrigin.getKeyUid()):
        self.controller.fetchAddressesFromNotImportedSeedPhrase(self.controller.getSeedPhrase(), paths)
        return
      if selectedOrigin.getMigratedToColdWallet():
        self.fetchDerivedAddressesFromColdWalletKeypair(selectedOrigin.getKeyUid(), paths)
        return
      let doPasswordHashing = not singletonInstance.userProfile.getMigratedToColdWallet()
      self.controller.fetchDerivedAddresses(selectedOrigin.getDerivedFrom(), paths, doPasswordHashing)
      return
  error "derivation is not supported for other than profile and seed imported keypairs for origin"

proc authenticateSelectedOrigin[T](self: Module[T], reason: AuthenticationReason) =
  let selectedOrigin = self.view.getSelectedOrigin()
  self.authenticationReason = reason
  if selectedOrigin.getMigratedToColdWallet():
    self.controller.setAuthenticatedKeyUid(selectedOrigin.getKeyUid())
    self.view.setActionAuthenticated(true)
    self.fetchAddressForDerivationPath()
    return
  self.view.emitAuthenticationRequested("")

method onUserAuthenticated*[T](self: Module[T], pin: string, password: string, keyUid: string) =
  if password.len == 0:
    info "unsuccessful authentication"
    return
  self.controller.setPassword(password)
  self.controller.setAuthenticatedKeyUid(keyUid)
  if self.authenticationReason == AuthenticationReason.AddingAccount:
    self.view.setDisablePopup(true)
    let selectedOrigin = self.view.getSelectedOrigin()
    if selectedOrigin.getPairType() == KeyPairType.PrivateKeyImport.int:
      self.doAddAccount() # we're sure that we need to add an account from priv key from here, cause derivation is not possible for imported priv key
      return
    self.fetchAddressForDerivationPath()
    return
  if self.authenticationReason == AuthenticationReason.EditingDerivationPath:
    self.view.setActionAuthenticated(true)
    self.fetchAddressForDerivationPath()

proc isAuthenticationNeededForSelectedOrigin[T](self: Module[T]): bool =
  let selectedOrigin = self.view.getSelectedOrigin()
  if selectedOrigin.isNil:
    error "selected origin is not set"
    return true
  if selectedOrigin.getPairType() == KeyPairType.Unknown.int and
    selectedOrigin.getKeyUid() == Label_OptionAddWatchOnlyAcc:
      return false
  if selectedOrigin.getKeyUid() == self.controller.getAuthenticatedKeyUid():
    return false
  if not selectedOrigin.getMigratedToColdWallet() and
    self.controller.getAuthenticatedKeyUid() == singletonInstance.userProfile.getKeyUid() and
    self.controller.getPassword().len > 0: # need this condition because cold wallet migrated profile does derive from xpub, without password
    return false
  return true

method changeDerivationPath*[T](self: Module[T], derivationPath: string) =
  self.view.setDerivationPath(derivationPath)
  if self.isAuthenticationNeededForSelectedOrigin():
    return
  self.fetchAddressForDerivationPath()

proc resolveSuggestedPathForSelectedOrigin[T](self: Module[T]): string =
  let selectedOrigin = self.view.getSelectedOrigin()
  return self.controller.resolveSuggestedPathForKeypair(selectedOrigin.getKeyUid())

method resetDerivationPath*[T](self: Module[T]) =
  let suggestedPath = self.resolveSuggestedPathForSelectedOrigin()
  self.changeDerivationPath(suggestedPath)

proc setItemForSelectedOrigin[T](self: Module[T], item: KeyPairItem) =
  if item.isNil:
    error "provided item cannot be set as selected origin", keyUid=item.getKeyUid()
    return

  let selectedOrigin = self.view.getSelectedOrigin()
  if selectedOrigin.getKeyUid() != item.getKeyUid():
    self.view.derivedAddressModel().reset()
    self.view.setSelectedDerivedAddress(newDerivedAddressItem())

  self.view.setSelectedOrigin(item)

  if item.getKeyUid() == Label_OptionAddWatchOnlyAcc:
    self.view.setWatchOnlyAccAddress(newDerivedAddressItem())
    return

  let suggestedPath = self.resolveSuggestedPathForSelectedOrigin()
  self.view.setSuggestedDerivationPath(suggestedPath)
  self.view.setDerivationPath(suggestedPath)

  if self.isAuthenticationNeededForSelectedOrigin():
    self.controller.setAuthenticatedKeyUid("")
    self.controller.setPassword("")
    self.view.setActionAuthenticated(false)
  else:
    self.fetchAddressForDerivationPath()

method changeSelectedOrigin*[T](self: Module[T], keyUid: string) =
  let item = self.view.originModel().findItemByKeyUid(keyUid)
  self.setItemForSelectedOrigin(item)

method changeSelectedDerivedAddress*[T](self: Module[T], address: string) =
  let item = self.view.derivedAddressModel().getItemByAddress(address)
  if item.isNil:
    error "cannot resolve derived address item by provided address", address=address
    return
  self.view.setSelectedDerivedAddress(item)
  self.view.setDerivationPath(item.getPath())
  self.view.setScanningForActivityIsOngoing(true)
  self.controller.fetchDetailsForAddresses(@[address])

method changeWatchOnlyAccountAddress*[T](self: Module[T], address: string) =
  self.view.setScanningForActivityIsOngoing(false)
  self.view.setWatchOnlyAccAddress(newDerivedAddressItem(order = 0, address = address))
  if address.len == 0:
    return
  self.view.setScanningForActivityIsOngoing(true)
  self.view.setWatchOnlyAccAddress(newDerivedAddressItem(order = 0, address = address))
  self.controller.fetchDetailsForAddresses(@[address])

method changePrivateKey*[T](self: Module[T], privateKey: string) =
  self.view.setScanningForActivityIsOngoing(false)
  self.view.setPrivateKeyAccAddress(newDerivedAddressItem())
  if privateKey.len == 0:
    return
  let genAccDto = self.controller.createAccountFromPrivateKey(privateKey)
  if genAccDto.address.len == 0:
    error "unable to resolve an address from the provided private key"
    return
  self.view.setScanningForActivityIsOngoing(true)
  self.view.setPrivateKeyAccAddress(newDerivedAddressItem(order = 0, address = genAccDto.address, publicKey = genAccDto.publicKey))
  self.controller.fetchDetailsForAddresses(@[genAccDto.address])

method changeSeedPhrase*[T](self: Module[T], seedPhrase: string) =
  self.view.setSelectedDerivedAddress(newDerivedAddressItem())
  if seedPhrase.len == 0:
    return
  let genAccDto = self.controller.createAccountFromSeedPhrase(seedPhrase)
  if seedPhrase.len > 0 and genAccDto.address.len == 0:
    error "unable to create an account from the provided seed phrase"
    return

method validSeedPhrase*[T](self: Module[T], seedPhrase: string): bool =
  let keyUid = self.controller.getKeyUidForSeedPhrase(seedPhrase)
  return not self.isKeyPairAlreadyAdded(keyUid)

proc setDerivedAddresses[T](self: Module[T], derivedAddresses: seq[DerivedAddressDto]) =
  defer: self.fetchingAddressesIsInProgress = false

  var items: seq[DerivedAddressItem]
  let derivationPath = self.view.getDerivationPath()
  if derivationPath.endsWith("/"):
    for i in 0 ..< self.getNumOfAddressesToGenerate():
      let path = derivationPath & $i
      for d in derivedAddresses:
        if d.path == path:
          items.add(newDerivedAddressItem(order = i, address = d.address, publicKey = d.publicKey, path = d.path, alreadyCreated = d.alreadyCreated))
          break
    self.view.derivedAddressModel().setItems(items)
  else:
    for d in derivedAddresses:
      if d.path == derivationPath:
        items.add(newDerivedAddressItem(order = 0, address = d.address, publicKey = d.publicKey, path = d.path, alreadyCreated = d.alreadyCreated))
        break
    self.view.derivedAddressModel().setItems(items)
    if items.len == 0:
      info "couldn't resolve an address for the set path"
      return
    self.changeSelectedDerivedAddress(items[0].getAddress())

method onDerivedAddressesFetched*[T](self: Module[T], derivedAddresses: seq[DerivedAddressDto], error: string) =
  if error.len > 0:
    error "fetching derived addresses error", err=error
    self.fetchingAddressesIsInProgress = false
    if self.authenticationReason == AuthenticationReason.AddingAccount:
      self.view.setDisablePopup(false)
    return

  let selectedOrigin = self.view.getSelectedOrigin()
  if selectedOrigin.getPairType() != KeyPairType.Profile.int and
    selectedOrigin.getPairType() != KeyPairType.SeedImport.int:
      error "received derived addresses reffer to profile or seed imported origin, but that's not the selected origin"
      return
  self.setDerivedAddresses(derivedAddresses)
  if self.authenticationReason == AuthenticationReason.AddingAccount:
    self.doAddAccount()

method onAddressesFromNotImportedMnemonicFetched*[T](self: Module[T], derivations: Table[string, DerivedAccountDetails], error: string) =
  if error.len > 0:
    error "fetching derived addresses from not imported mnemonic error", err=error
    return
  let selectedOrigin = self.view.getSelectedOrigin()
  if selectedOrigin.getPairType() != KeyPairType.SeedImport.int:
    error "received derived addresses from not imported mnemonic reffer to seed imported origin, but that's not the selected origin"
    return
  var derivedAddresses: seq[DerivedAddressDto]
  for path, data in derivations.pairs:
    derivedAddresses.add(DerivedAddressDto(
      address: data.address,
      publicKey: data.publicKey,
      path: path,
      hasActivity: false,
      alreadyCreated: false)
    )
  self.setDerivedAddresses(derivedAddresses)
  if self.authenticationReason == AuthenticationReason.AddingAccount:
    self.doAddAccount()


method updateDerivedAddresses*[T](self: Module[T], derivedAddresses: seq[DerivedAddressDto], error: string, detailsLoaded: bool) =
  if not self.view.getScanningForActivityIsOngoing():
    return
  var errorInCheckedIfAccountAlreadyExists = error.len > 0 and not detailsLoaded
  var errorInScanningActivity = error.len > 0 and detailsLoaded
  if errorInScanningActivity:
    error "fetching address details error", err=error
  let currStateObj = self.view.currentStateObj()
  if currStateObj.isNil:
    error "waa_cannot resolve current state"
    return

  # we always receive responses one by one
  if derivedAddresses.len == 1:
    var addressDetailsItem = newDerivedAddressItem(order = 0,
      address = derivedAddresses[0].address,
      publicKey = derivedAddresses[0].publicKey,
      path = derivedAddresses[0].path,
      alreadyCreated = derivedAddresses[0].alreadyCreated,
      hasActivity = derivedAddresses[0].hasActivity,
      alreadyCreatedChecked = not errorInCheckedIfAccountAlreadyExists,
      detailsLoaded = detailsLoaded,
      errorInScanningActivity = errorInScanningActivity)
    if currStateObj.stateType() == StateType.EnterPrivateKey:
      if cmpIgnoreCase(self.view.getPrivateKeyAccAddress().getAddress(), addressDetailsItem.getAddress()) == 0:
        self.view.setPrivateKeyAccAddress(addressDetailsItem)
        return
    elif currStateObj.stateType() == StateType.Main:
      let selectedOrigin = self.view.getSelectedOrigin()
      if selectedOrigin.getPairType() == KeyPairType.Unknown.int and
        selectedOrigin.getKeyUid() == Label_OptionAddWatchOnlyAcc and
        cmpIgnoreCase(self.view.getWatchOnlyAccAddress().getAddress(), addressDetailsItem.getAddress()) == 0:
          self.view.setWatchOnlyAccAddress(addressDetailsItem)
          return
      let selectedAddress = self.view.getSelectedDerivedAddress()
      if cmpIgnoreCase(selectedAddress.getAddress(), addressDetailsItem.getAddress()) == 0:
        addressDetailsItem.setPublicKey(selectedAddress.getPublicKey())
        addressDetailsItem.setPath(selectedAddress.getPath())
        self.view.setSelectedDerivedAddress(addressDetailsItem)
      self.view.derivedAddressModel().updateDetailsForAddressAndBubbleItToTop(addressDetailsItem.getAddress(),
      addressDetailsItem.getHasActivity(),
      detailsLoaded, errorInScanningActivity)
      return
    error "derived addresses received in the state in which the app doesn't expect them"
    return
  error "unknown error, since the length of the response is not expected", length=derivedAddresses.len

method startScanningForActivity*[T](self: Module[T]) =
  self.view.setScanningForActivityIsOngoing(true)
  let allAddresses = self.view.derivedAddressModel().getAllAddresses()
  self.controller.fetchDetailsForAddresses(allAddresses)

method authenticateForEditingDerivationPath*[T](self: Module[T]) =
  self.authenticateSelectedOrigin(AuthenticationReason.EditingDerivationPath)

proc doAddAccount[T](self: Module[T]) =
  self.view.setDisablePopup(true)
  let
    selectedOrigin = self.view.getSelectedOrigin()
    selectedAddrItem = self.view.getSelectedDerivedAddress()
  var
    addingNewKeyPair = false
    accountType: string
    keypairName = selectedOrigin.getName()
    address = selectedAddrItem.getAddress()
    path = selectedAddrItem.getPath()
    publicKey = selectedAddrItem.getPublicKey()
    rootWalletMasterKey = selectedOrigin.getDerivedFrom()
    keyUid = selectedOrigin.getKeyUid()
    createKeystoreFile = not selectedOrigin.getMigratedToColdWallet()
    doPasswordHashing = not singletonInstance.userProfile.getMigratedToColdWallet()
    hideFromTotalBalance = false

  if selectedOrigin.getPairType() == KeyPairType.Profile.int:
    accountType = account_constants.GENERATED
  elif selectedOrigin.getPairType() == KeyPairType.SeedImport.int:
    accountType = account_constants.SEED
    addingNewKeyPair = not self.isKeyPairAlreadyAdded(keyUid)
  elif selectedOrigin.getPairType() == KeyPairType.PrivateKeyImport.int:
    let genAcc = self.controller.getGeneratedAccount()
    accountType = account_constants.KEY
    address = genAcc.address
    path = "m" # from private key an address for path `m` is generate (corresponds to the master key address)
    rootWalletMasterKey = ""
    publicKey = genAcc.publicKey
    keyUid = genAcc.keyUid
    addingNewKeyPair = not self.isKeyPairAlreadyAdded(keyUid)
  else:
    accountType = account_constants.WATCH
    hideFromTotalBalance = true
    createKeystoreFile = false
    doPasswordHashing = false
    keypairName = ""
    address = self.view.getWatchOnlyAccAddress().getAddress()
    path = ""
    rootWalletMasterKey = ""
    publicKey = ""
    keyUid = ""

  let savedAddressDto = self.controller.getSavedAddress(address)
  if not savedAddressDto.isNil:
    self.view.sendConfirmSavedAddressRemovalSignal(savedAddressDto.name, savedAddressDto.address)
    return

  var success = false
  if addingNewKeyPair:
    if selectedOrigin.getPairType() == KeyPairType.PrivateKeyImport.int:
      success = self.controller.addNewPrivateKeyKeypair(
        privateKey = self.controller.getGeneratedAccount().privateKey,
        doPasswordHashing = not singletonInstance.userProfile.getMigratedToColdWallet(),
        keypairName = keypairName,
        accountCreationDetails = AccountCreationDetails(
            path: path,
            name: self.view.getAccountName(),
            colorId: self.view.getSelectedColorId(),
            emoji: self.view.getSelectedEmoji()
          )
        )
      if not success:
        error "failed to store new private key account", address=selectedAddrItem.getAddress()
    elif selectedOrigin.getPairType() == KeyPairType.SeedImport.int:
      success = self.controller.addNewSeedPhraseKeypair(
        seedPhrase = self.controller.getSeedPhrase(),
        doPasswordHashing = not singletonInstance.userProfile.getMigratedToColdWallet(),
        keypairName = keypairName,
        accountCreationDetails = AccountCreationDetails(
            path: path,
            name: self.view.getAccountName(),
            colorId: self.view.getSelectedColorId(),
            emoji: self.view.getSelectedEmoji()
          )
        )
      if not success:
        error "failed to store new seed phrase account", address=selectedAddrItem.getAddress()
  else:
    success = self.controller.addWalletAccount(
      createKeystoreFile = createKeystoreFile,
      doPasswordHashing = doPasswordHashing,
      name = self.view.getAccountName(),
      address = address,
      path = path,
      publicKey = publicKey,
      keyUid = keyUid,
      accountType = accountType,
      colorId = self.view.getSelectedColorId(),
      emoji = self.view.getSelectedEmoji(),
      hideFromTotalBalance = hideFromTotalBalance)
    if not success:
      error "failed to store account", address=selectedAddrItem.getAddress()

  self.closeAddAccountPopup()

method removingSavedAddressConfirmed[T](self: Module[T], address: string) =
  self.controller.deleteSavedAddress(address)

method savedAddressDeleted*[T](self: Module[T], address: string, errorMsg: string) =
  if errorMsg.len > 0:
    error "failed to delete saved address", address=address, err=errorMsg
    return
  self.doAddAccount()

proc doEditAccount[T](self: Module[T]) =
  self.view.setDisablePopup(true)
  let selectedOrigin = self.view.getSelectedOrigin()

  var address = self.view.getWatchOnlyAccAddress().getAddress()
  if selectedOrigin.getPairType() == KeyPairType.Profile.int or
    selectedOrigin.getPairType() == KeyPairType.SeedImport.int:
      let selectedAddrItem = self.view.getSelectedDerivedAddress()
      address = selectedAddrItem.getAddress()
  elif selectedOrigin.getPairType() == KeyPairType.PrivateKeyImport.int:
      let selectedAddrItem = self.view.getPrivateKeyAccAddress()
      address = selectedAddrItem.getAddress()

  if self.controller.updateAccount(
    address = address,
    accountName = self.view.getAccountName(),
    colorId = self.view.getSelectedColorId(),
    emoji = self.view.getSelectedEmoji()):
      self.closeAddAccountPopup()
  else:
    self.closeAddAccountPopup()

method finalizeAction*[T](self: Module[T]) =
  if self.view.getEditMode():
    self.doEditAccount()
    return
  if self.isAuthenticationNeededForSelectedOrigin():
    self.authenticateSelectedOrigin(AuthenticationReason.AddingAccount)
    return
  self.doAddAccount()

method buildNewPrivateKeyKeypairAndAddItToOrigin*[T](self: Module[T]) =
  let genAcc = self.controller.getGeneratedAccount()
  var item = newKeyPairItem(keyUid = genAcc.keyUid,
    pubKey = genAcc.publicKey,
    locked = false,
    name = self.view.getNewKeyPairName(),
    image = "",
    icon = "key_pair_private_key",
    pairType = KeyPairType.PrivateKeyImport)
  self.setItemForSelectedOrigin(item)

method buildNewSeedPhraseKeypairAndAddItToOrigin*[T](self: Module[T]) =
  let genAcc = self.controller.getGeneratedAccount()

  var item = newKeyPairItem(keyUid = genAcc.keyUid,
    pubKey = genAcc.publicKey,
    locked = false,
    name = self.view.getNewKeyPairName(),
    image = "",
    icon = "key_pair_seed_phrase",
    pairType = KeyPairType.SeedImport,
    derivedFrom = genAcc.address)
  self.setItemForSelectedOrigin(item)

method isChecksumValidForAddress*[T](self: Module[T], address: string): bool =
  return self.controller.isChecksumValidForAddress(address)

method remainingAccountCapacity*[T](self: Module[T]): int =
  return self.controller.remainingAccountCapacity()

method remainingKeypairCapacity*[T](self: Module[T]): int =
  return self.controller.remainingKeypairCapacity()

method remainingWatchOnlyAccountCapacity*[T](self: Module[T]): int =
  return self.controller.remainingWatchOnlyAccountCapacity()

{.pop.}
