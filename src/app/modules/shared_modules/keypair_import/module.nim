import nimqml, strutils, chronicles

import io_interface
import view, controller
import internal/[state, state_factory]

import app/global/global_singleton
import app/core/eventemitter
import app/modules/shared/keypairs
import app/modules/shared_models/[keypair_model, derived_address_model]
import app_service/service/accounts/service as accounts_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/devices/service as devices_service

export io_interface

logScope:
  topics = "wallet-keypair-import-module"

type
  Module*[T: io_interface.DelegateInterface] = ref object of io_interface.AccessInterface
    delegate: T
    events: EventEmitter
    view: View
    viewVariant: QVariant
    controller: Controller
    tmpPassword: string

proc newModule*[T](delegate: T,
  events: EventEmitter,
  accountsService: accounts_service.Service,
  walletAccountService: wallet_account_service.Service,
  devicesService: devices_service.Service):
  Module[T] =
  result = Module[T]()
  result.delegate = delegate
  result.view = newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, events, accountsService, walletAccountService, devicesService)

{.push warning[Deprecated]: off.}

method delete*[T](self: Module[T]) =
  self.view.delete
  self.viewVariant.delete
  self.controller.delete

method closeKeypairImportPopup*[T](self: Module[T]) =
  self.delegate.destroyKeypairImportPopup()

method getModuleAsVariant*[T](self: Module[T]): QVariant =
  return self.viewVariant

method load*[T](self: Module[T], keyUid: string, mode: ImportKeypairModuleMode) =
  self.controller.init()
  if mode == ImportKeypairModuleMode.SelectKeypair:
    let items = keypairs.buildKeyPairsList(self.controller.getKeypairs(), excludeAlreadyMigratedPairs = true,
      excludePrivateKeyKeypairs = false)
    self.view.createKeypairModel(items)
    self.view.setCurrentState(newSelectKeypairState(nil))
  else:
    self.view.setSelectedKeypairItem(newKeyPairItem(keyUid = keyUid))
    let keypair = self.controller.getKeypairByKeyUid(keyUid)
    if not keypair.isNil:
      self.view.getSelectedKeypair().setName(keypair.name)
    if mode == ImportKeypairModuleMode.ExportKeypairQr:
      self.view.setCurrentState(newExportKeypairState(nil))
      self.controller.authenticateLoggedInUser()
      return
    elif mode == ImportKeypairModuleMode.ImportViaQr:
      self.view.setCurrentState(newImportQrState(nil))
      self.delegate.onKeypairImportModuleLoaded()
      return
    if keypair.isNil:
      error "ki_trying to import an unknown keypair"
      self.closeKeypairImportPopup()
      return
    let keypairItem = buildKeypairItem(keypair, areTestNetworksEnabled = false) # testnetworks are irrelevant in this context
    if keypairItem.isNil:
      error "ki_cannot generate keypair item for provided keypair"
      self.closeKeypairImportPopup()
      return
    self.view.setSelectedKeypairItem(keypairItem)
    if mode == ImportKeypairModuleMode.SelectImportMethod:
      self.view.setCurrentState(newSelectImportMethodState(nil))
    elif mode == ImportKeypairModuleMode.ImportViaPrivateKey:
      self.view.setCurrentState(newImportPrivateKeyState(nil))
    elif mode == ImportKeypairModuleMode.ImportViaSeedPhrase:
      self.view.setCurrentState(newImportSeedPhraseState(nil))
  self.delegate.onKeypairImportModuleLoaded()

method onBackActionClicked*[T](self: Module[T]) =
  let currStateObj = self.view.currentStateObj()
  if currStateObj.isNil:
    error "ki_cannot resolve current state"
    return
  debug "ki_back_action", currState=currStateObj.stateType()
  currStateObj.executePreBackStateCommand(self.controller)
  let backState = currStateObj.getBackState()
  if backState.isNil:
    return
  self.view.setCurrentState(backState)
  debug "ki_back_action - set state", newCurrState=backState.stateType()

method onCancelActionClicked*[T](self: Module[T]) =
  let currStateObj = self.view.currentStateObj()
  if currStateObj.isNil:
    error "ki_cannot resolve current state"
    return
  debug "ki_cancel_action", currState=currStateObj.stateType()
  currStateObj.executeCancelCommand(self.controller)

method onPrimaryActionClicked*[T](self: Module[T]) =
  let currStateObj = self.view.currentStateObj()
  if currStateObj.isNil:
    error "ki_cannot resolve current state"
    return
  debug "ki_primary_action", currState=currStateObj.stateType()
  currStateObj.executePrePrimaryStateCommand(self.controller)
  let nextState = currStateObj.getNextPrimaryState(self.controller)
  if nextState.isNil:
    return
  self.view.setCurrentState(nextState)
  debug "ki_primary_action - set state", setCurrState=nextState.stateType()

method onSecondaryActionClicked*[T](self: Module[T]) =
  let currStateObj = self.view.currentStateObj()
  if currStateObj.isNil:
    error "ki_cannot resolve current state"
    return
  debug "ki_secondary_action", currState=currStateObj.stateType()
  currStateObj.executePreSecondaryStateCommand(self.controller)
  let nextState = currStateObj.getNextSecondaryState(self.controller)
  if nextState.isNil:
    return
  self.view.setCurrentState(nextState)
  debug "ki_secondary_action - set state", setCurrState=nextState.stateType()

method getSelectedKeypair*[T](self: Module[T]): KeyPairItem =
  return self.view.getSelectedKeypair()

method clearSelectedKeypair*[T](self: Module[T]) =
  self.view.setSelectedKeypairItem(newKeyPairItem())

method setSelectedKeyPairByKeyUid*[T](self: Module[T], keyUid: string) =
  let item = self.view.keypairModel().findItemByKeyUid(keyUid)
  if item.isNil:
    error "ki_cannot generate keypair item for provided keypair"
    self.closeKeypairImportPopup()
    return
  self.view.setSelectedKeypairItem(item)

method changePrivateKey*[T](self: Module[T], privateKey: string) =
  self.view.setPrivateKeyAccAddress(newDerivedAddressItem())
  if privateKey.len == 0:
    return
  let genAccDto = self.controller.createAccountFromPrivateKey(privateKey)
  if genAccDto.address.len == 0:
    error "ki_unable to resolve an address from the provided private key"
    return
  let kp = self.view.getSelectedKeypair()
  if kp.isNil:
    # should never be here
    return
  if kp.getKeyUid() != genAccDto.keyUid:
    self.view.setEnteredPrivateKeyMatchTheKeypair(false)
    error "ki_entered private key doesn't refer to a keyapir being imported"
    return
  self.view.setEnteredPrivateKeyMatchTheKeypair(true)
  self.view.setPrivateKeyAccAddress(newDerivedAddressItem(order = 0, address = genAccDto.address, publicKey = genAccDto.publicKey))
  self.controller.fetchDetailsForAddresses(@[genAccDto.address])

method changeSeedPhrase*[T](self: Module[T], seedPhrase: string) =
  if seedPhrase.len == 0:
    return
  let genAccDto = self.controller.createAccountFromSeedPhrase(seedPhrase)
  if seedPhrase.len > 0 and genAccDto.address.len == 0:
    error "ki_unable to create an account from the provided seed phrase"
    return

method validSeedPhrase*[T](self: Module[T], seedPhrase: string): bool =
  let genAccDto = self.controller.createAccountFromSeedPhrase(seedPhrase)
  let kp = self.view.getSelectedKeypair()
  if kp.isNil:
    # should never be here
    return false
  return kp.getKeyUid() == genAccDto.keyUid

method onAddressDetailsFetched*[T](self: Module[T], derivedAddresses: seq[DerivedAddressDto], error: string) =
  if error.len > 0:
    error "ki_fetching address details error", err=error
    return
  let currStateObj = self.view.currentStateObj()
  if currStateObj.isNil:
    error "ki_cannot resolve current state"
    return
  # we always receive responses one by one
  if derivedAddresses.len == 1:
    var addressDetailsItem = newDerivedAddressItem(order = 0,
      address = derivedAddresses[0].address,
      publicKey = derivedAddresses[0].publicKey,
      path = derivedAddresses[0].path,
      alreadyCreated = derivedAddresses[0].alreadyCreated,
      hasActivity = derivedAddresses[0].hasActivity,
      alreadyCreatedChecked = true,
      detailsLoaded = true)
    if currStateObj.stateType() == StateType.ImportPrivateKey:
      if cmpIgnoreCase(self.view.getPrivateKeyAccAddress().getAddress(), addressDetailsItem.getAddress()) == 0:
        self.view.setPrivateKeyAccAddress(addressDetailsItem)
        return
  error "ki_unknown error, since the length of the response is not expected", length=derivedAddresses.len

method setConnectionString*[T](self: Module[T], connectionString: string) =
  self.view.setConnectionString(connectionString)

method generateConnectionStringForExporting*[T](self: Module[T]) =
  self.view.setConnectionString("")
  self.view.setConnectionStringError("")
  let currStateObj = self.view.currentStateObj()
  if currStateObj.isNil:
    error "ki_cannot resolve current state"
    return
  if currStateObj.stateType() == StateType.ExportKeypair:
    var keyUids: seq[string]
    let keyUid = self.view.getSelectedKeypair().getKeyUid()
    if keyUid.len > 0:
      keyUids.add(keyUid)
    let (connectionString, err) = self.controller.generateConnectionStringForExportingKeypairsKeystores(keyUids, self.tmpPassword)
    if err.len > 0:
      self.view.setConnectionStringError(err)
      return
    self.view.setConnectionString(connectionString)

method validateConnectionString*[T](self: Module[T], connectionString: string): string =
  return self.controller.validateConnectionString(connectionString)

method onAuthenticationRequest*[T](self: Module[T]) =
  self.view.emitAuthenticationRequested(singletonInstance.userProfile.getKeyUid())

method onUserAuthenticated*[T](self: Module[T], pin: string, password: string, keyUid: string) =
  if password.len == 0:
    info "ki_unsuccessful authentication"
    return
  let currStateObj = self.view.currentStateObj()
  if currStateObj.isNil:
    error "ki_cannot resolve current state"
    return
  if currStateObj.stateType() == StateType.ExportKeypair:
    self.tmpPassword = password
    self.generateConnectionStringForExporting()
    self.delegate.onKeypairImportModuleLoaded()
    return
  if currStateObj.stateType() == StateType.ImportQr:
    var keyUids: seq[string]
    let keyUid = self.view.getSelectedKeypair().getKeyUid()
    if keyUid.len > 0:
      keyUids.add(keyUid)
    let res = self.controller.inputConnectionStringForImportingKeypairsKeystores(keyUids, self.view.getConnectionString(), password)
    if res.len > 0:
      error "ki_unable to make a keypair operable", errDesription=res
      return
  if currStateObj.stateType() == StateType.ImportPrivateKey:
    let res = self.controller.makePrivateKeyKeypairFullyOperable(self.controller.getGeneratedAccount().keyUid,
      self.controller.getPrivateKey(),
      password,
      doPasswordHashing = not singletonInstance.userProfile.getMigratedToColdWallet())
    if res.len > 0:
      error "ki_unable to make a keypair operable", errDesription=res
      return
  if currStateObj.stateType() == StateType.ImportSeedPhrase:
    let res = self.controller.makeSeedPhraseKeypairFullyOperable(self.controller.getGeneratedAccount().keyUid,
      self.controller.getSeedPhrase(),
      password,
      doPasswordHashing = not singletonInstance.userProfile.getMigratedToColdWallet())
    if res.len > 0:
      error "ki_unable to make a keypair operable", errDesription=res
      return
  self.closeKeypairImportPopup()

{.pop.}
