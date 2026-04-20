import nimqml, sugar, strutils, sequtils, chronicles, json, json_serialization

import io_interface
import view, controller
import app/core/eventemitter
import app/modules/shared/keypairs

import app_service/common/account_constants
import app_service/common/utils
import app_service/service/keycardV2/service as keycard_serviceV2
import app_service/service/accounts/service as accounts_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/privacy/service as privacy_service

export io_interface

logScope:
  topics = "keycard-management-module"

type AccountData = object
  name: string
  colorId: string
  emoji: string
  path: string
  address: string
  publicKey: string

type FlowType {.pure.} = enum
  ImportingKeyPair = "ImportingKeyPair"
  MigratingNonProfileKeypairToKeycard = "MigratingNonProfileKeypairToKeycard"
  MigratingProfileKeypairToKeycard = "MigratingProfileKeypairToKeycard"
  AddingKeyPairFromKeycard = "AddingKeyPairFromKeycard"

type
  Module*[T: io_interface.DelegateInterface] = ref object of io_interface.AccessInterface
    delegate: T
    view: View
    viewVariant: QVariant
    controller: Controller
    tmpFlowType: FlowType
    tmpPassword: string
    tmpKeyUid: string
    tmpKeypairName: string
    tmpXpub: string
    tmpAccountsData: seq[AccountData]
    tmpSeedPhrase: string
    tmpMetadataAccountsJson: string

proc newModule*[T](delegate: T,
  events: EventEmitter,
  keycardServiceV2: keycard_serviceV2.Service,
  accountsService: accounts_service.Service,
  walletAccountService: wallet_account_service.Service,
  privacyService: privacy_service.Service):
  Module[T] =
  result = Module[T]()
  result.delegate = delegate
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, events, keycardServiceV2, accountsService, walletAccountService, privacyService)
  result.controller.init()

{.push warning[Deprecated]: off.}

method delete*[T](self: Module[T]) =
  self.view.delete
  self.viewVariant.delete
  self.controller.delete

method getModuleAsVariant*[T](self: Module[T]): QVariant =
  return self.viewVariant

method startGetMetadata*[T](self: Module[T], pin: string) =
  self.controller.startGetMetadata(pin)

method stopKeycardAction*[T](self: Module[T]) =
  self.controller.stopKeycardAction()

method onKeycardStateUpdated*[T](self: Module[T], kcEvent: KeycardEventDto) =
  self.view.setKeycardState($kcEvent.stateString)
  self.view.setRemainingPinAttempts(kcEvent.keycardStatus.remainingAttemptsPIN)
  self.view.setRemainingPukAttempts(kcEvent.keycardStatus.remainingAttemptsPUK)
  self.view.setAvailableSlots(kcEvent.keycardInfo.availableSlots)
  self.view.setKeyUid(kcEvent.keycardInfo.keyUID)
  self.view.setKeycardUid(kcEvent.keycardInfo.instanceUID)

method onKeycardGetMetadataFinished*[T](self: Module[T], metadata: CardMetadataDto, error: string) =
  if error.len > 0:
    error "keycard get metadata error", error=error
    self.view.keycardGetMetadataError(error)
    return
  self.view.setCardMetadataName(metadata.name)
  var walletsJson = newJArray()
  for acc in metadata.walletAccounts:
    walletsJson.add(%*{
      "path": acc.path,
      "address": acc.address,
      "publicKey": acc.publicKey,
    })
  self.view.setCardMetadataWalletAccountsJson($walletsJson)
  self.view.keycardGetMetadataSuccess()

method startFactoryReset*[T](self: Module[T], keycardUid: string) =
  self.controller.startFactoryReset(keycardUid)

method onKeycardFactoryResetFinished*[T](self: Module[T], error: string) =
  if error.len > 0:
    error "keycard factory reset error", error=error
    self.view.keycardFactoryResetError(error)
    return
  self.view.keycardFactoryResetSuccess()

method getKeyUidForSeedPhrase*[T](self: Module[T], seedPhrase: string): string =
  return self.controller.getKeyUidForSeedPhrase(seedPhrase)

method isKnownKeyUid*[T](self: Module[T], keyUid: string): bool =
  let keypair = self.controller.getKeypairByKeyUid(keyUid)
  if keypair.isNil or keypair.removed:
    return false
  return true

method getKeyPairNameForKeyUid*[T](self: Module[T], keyUid: string): string =
  let keypair = self.controller.getKeypairByKeyUid(keyUid)
  if keypair.isNil or keypair.removed:
    return ""
  return keypair.name

method getKeyPairAccountPathsJsonForKeyUid*[T](self: Module[T], keyUid: string): string =
  let keypair = self.controller.getKeypairByKeyUid(keyUid)
  if keypair.isNil or keypair.removed:
    return "[]"
  var paths = newJArray()
  for acc in keypair.accounts:
    paths.add(%*{"path": acc.path})
  return $paths

proc prepareAccountsData[T](self: Module[T], extendedPublicKey: string, metadataAccounts: string): bool =
  try:
    self.tmpAccountsData = Json.decode(metadataAccounts, seq[AccountData])
  except Exception as e:
    error "error parsing account data json", err=e.msg
    return false

  # only keep paths that are under the wallet xpub path and make them relative to the wallet xpub path
  let relativePaths = self.tmpAccountsData.filter(a => a.path.startsWith(PATH_WALLET_XPUB)).
    map(a => a.path.replace(PATH_WALLET_XPUB&"/", ""))

  let derivedAccounts = self.controller.deriveAccountsPublicInfoFromExtendedPublicKeyForPaths(extendedPublicKey, relativePaths)
  if derivedAccounts.derivations.len == 0:
    error "failed to derive accounts"
    return false

  for path, account in derivedAccounts.derivations:
    var idx = -1
    for i in 0 ..< self.tmpAccountsData.len:
      if self.tmpAccountsData[i].path.endsWith(path):
        idx = i
        break
    if idx < 0:
      error "account data not found for path", path=path
      return false
    self.tmpAccountsData[idx].address = account.address
    self.tmpAccountsData[idx].publicKey = account.publicKey
  return true

proc emitError[T](self: Module[T], err: string) =
  error "emitting error", err=err
  if self.tmpFlowType == FlowType.ImportingKeyPair:
    self.view.keycardImportKeyPairError(err)
  elif self.tmpFlowType == FlowType.MigratingNonProfileKeypairToKeycard:
    self.view.keycardMoveKeyPairError(err)
  elif self.tmpFlowType == FlowType.MigratingProfileKeypairToKeycard:
    self.view.keycardMoveProfileKeyPairError(err)
  elif self.tmpFlowType == FlowType.AddingKeyPairFromKeycard:
    self.view.keycardAddKeyPairError(err)
  else:
    error "invalid flow type", flowType=($self.tmpFlowType)

proc startLoadSeedPhrase[T](self: Module[T], pin: string, seedPhrase: string, metadataName: string, metadataAccounts: string) =
  self.tmpKeypairName = metadataName
  self.tmpKeyUid = self.controller.getKeyUidForSeedPhrase(seedPhrase)
  if self.tmpKeyUid.len == 0:
    self.emitError("failed to get key uid for seed phrase")
    return

  self.tmpXpub = self.controller.deriveExtendedPublicKeyAtPath(seedPhrase, passphrase = "", PATH_WALLET_XPUB)
  if self.tmpXpub.len == 0:
    self.emitError("failed to derive extended public key")
    return

  if not self.prepareAccountsData(self.tmpXpub, metadataAccounts):
    self.emitError("failed to prepare accounts data")
    return

  let puk = keycard_serviceV2.generateRandomPUK()
  let paths = self.tmpAccountsData.map(a => a.path)
  self.controller.startLoadSeedPhrase(pin, puk, seedPhrase, metadataName, paths)

method startImportingKeyPair*[T](self: Module[T], pin: string, seedPhrase: string, metadataName: string,
    metadataAccounts: string) =
  self.tmpFlowType = FlowType.ImportingKeyPair
  self.startLoadSeedPhrase(pin, seedPhrase, metadataName, metadataAccounts)

method startMigratingNonProfileKeypairToKeycard*[T](self: Module[T], password: string, pin: string, seedPhrase: string) =
  self.tmpFlowType = FlowType.MigratingNonProfileKeypairToKeycard
  self.tmpPassword = utils.hashPassword(password)
  let keyUid = self.controller.getKeyUidForSeedPhrase(seedPhrase)
  let metadataName = self.getKeyPairNameForKeyUid(keyUid)
  let metadataAccounts = self.getKeyPairAccountPathsJsonForKeyUid(keyUid)
  self.startLoadSeedPhrase(pin, seedPhrase, metadataName, metadataAccounts)

method isMnemonicBackedUp*[T](self: Module[T]): bool =
  return self.controller.isMnemonicBackedUp()

method getMnemonic*[T](self: Module[T]): string =
  return self.controller.getMnemonic()

method startMigratingProfileKeypairToKeycard*[T](self: Module[T], password: string, pin: string, seedPhrase: string) =
  self.tmpFlowType = FlowType.MigratingProfileKeypairToKeycard
  self.tmpPassword = password # don't hash it here, cause it's hashed in the service (TODO: change that and use hashPassword instead, from this line)
  self.tmpSeedPhrase = seedPhrase
  let keyUid = self.controller.getKeyUidForSeedPhrase(seedPhrase)
  let metadataName = self.getKeyPairNameForKeyUid(keyUid)
  let metadataAccounts = self.getKeyPairAccountPathsJsonForKeyUid(keyUid)
  self.startLoadSeedPhrase(pin, seedPhrase, metadataName, metadataAccounts)

method onConvertingProfileKeypairFinished*[T](self: Module[T], success: bool) =
  if not success:
    self.emitError("failed to convert profile keypair to keycard")
    return
  self.view.keycardMoveProfileKeyPairSuccess()

proc addNewKeycardKeypair*[T](self: Module[T]): string =
  var walletAccounts: seq[wallet_account_service.WalletAccountDto]
  for account in self.tmpAccountsData:
    walletAccounts.add(wallet_account_service.WalletAccountDto(
      keyUid: self.tmpKeyUid,
      name: account.name,
      path: account.path,
      address: account.address,
      publicKey: account.publicKey,
      walletType: SEED,
      colorId: account.colorId,
      emoji: account.emoji,
    ))
  return self.controller.addNewKeycardStoredKeypair(self.tmpKeyUid, self.tmpKeypairName, self.tmpXpub,
    wallet_account_service.ColdWalletTypeStatusKeycard, walletAccounts)

## #########################################################
## TODO: remove the part below once we remove the keycard management on the status-go side
## For now, we just add a new keycard and don't care (listen for signal) about the result of that operation
proc saveKeypairToKeycard[T](self: Module[T]) =
  let keyPair = KeycardDto(
    keycardUid: self.view.getKeycardUid(),
    keyUid: self.tmpKeyUid,
    keycardName: self.tmpKeypairName,
    keycardLocked: false,
    accountsAddresses: self.tmpAccountsData.map(a => a.address),
  )
  self.controller.addKeycardOrAccounts(keyPair, self.tmpPassword) # this call is removing local keystore files, we will need a new function for this, once we remove the keycard management on the status-go side
## #########################################################

method generateMnemonic*[T](self: Module[T]): string =
  return self.controller.generateMnemonic()

method populateKeyPairModel*[T](self: Module[T]) =
  let items = keypairs.buildKeyPairsList(self.controller.getKeypairs(), excludeAlreadyMigratedPairs = true,
    excludePrivateKeyKeypairs = false)
  self.view.createKeyPairModel(items)

method startAddingKeyPairToStatusFromKeycard*[T](self: Module[T], pin: string, keyUid: string,
    metadataName: string, metadataAccounts: string) =
  self.tmpFlowType = FlowType.AddingKeyPairFromKeycard
  self.tmpKeyUid = keyUid
  self.tmpKeypairName = metadataName
  self.tmpMetadataAccountsJson = metadataAccounts
  self.controller.startExportExtendedPublicKey(self.tmpKeyUid, PATH_WALLET_XPUB, pin)

method onKeycardExportExtendedPublicKeyFinished*[T](self: Module[T], xpub: string, error: string) =
  if self.tmpFlowType != FlowType.AddingKeyPairFromKeycard:
    return
  if error.len > 0:
    self.emitError("keycard export extended public key error: " & error)
    return
  if xpub.len == 0:
    self.emitError("keycard export extended public key returned empty xpub")
    return

  self.tmpXpub = xpub

  if not self.prepareAccountsData(self.tmpXpub, self.tmpMetadataAccountsJson):
    self.emitError("failed to prepare accounts data")
    return

  # additional check to protect against adding a key pair which is already in the db, in case `startAddingKeyPairToStatusFromKeycard` is not called from the DetailsView
  if self.isKnownKeyUid(self.tmpKeyUid):
    self.emitError("key pair already exists in db, cannot be added, keyUid: " & self.tmpKeyUid)
    return

  self.view.keycardInteractionSuccessfullyCompleted()

  let err = self.addNewKeycardKeypair()
  if err.len > 0:
    self.emitError("failed to add new keycard stored keypair: " & err)
    return

  self.saveKeypairToKeycard()
  self.view.keycardAddKeyPairSuccess()

method onKeycardLoadSeedPhraseFinished*[T](self: Module[T], error: string) =
  if error.len > 0:
    self.emitError("keycard load key pair error: " & error)
    return

  self.view.keycardInteractionSuccessfullyCompleted() # this signal is used to switch from the kreycard states to progressing statess

  if self.tmpFlowType == FlowType.ImportingKeyPair:
    if self.isKnownKeyUid(self.tmpKeyUid):
      self.emitError("key pair already exists in db, cannot be imported, keyUid: " & self.tmpKeyUid)
      return
    let err = self.addNewKeycardKeypair()
    if err.len > 0:
      self.emitError("failed to add new keycard stored keypair: " & err)
      return
    self.saveKeypairToKeycard() # this is just to add keycard to db and remove keystore files
    self.view.keycardImportKeyPairSuccess()
  elif self.tmpFlowType == FlowType.MigratingNonProfileKeypairToKeycard:
    let error = self.controller.updateKeypairExtendedPublicKey(self.tmpKeyUid, self.tmpXpub, wallet_account_service.ColdWalletTypeStatusKeycard)
    if error.len > 0:
      self.emitError("failed to update keypair extended public key: " & error & " for key uid: " & self.tmpKeyUid)
      return
    self.saveKeypairToKeycard() # this is just to add keycard to db and remove keystore files
    self.view.keycardMoveKeyPairSuccess()
  elif self.tmpFlowType == FlowType.MigratingProfileKeypairToKeycard:
    let acc = self.controller.createAccountFromMnemonic(self.tmpSeedPhrase, includeEncryption = true)
    let newPassword = acc.derivedAccounts.encryption.publicKey
    if newPassword.len == 0:
      self.emitError("failed to derive encryption public key from seed phrase")
      return
    self.controller.setStoreToKeychainValueNotNow()
    let err = self.controller.updateKeypairExtendedPublicKey(self.tmpKeyUid, self.tmpXpub, wallet_account_service.ColdWalletTypeStatusKeycard)
    if err.len > 0:
      self.emitError("failed to update keypair extended public key: " & err & " for key uid: " & self.tmpKeyUid)
      return
    let keycardUid = self.view.getKeycardUid()
    self.controller.convertRegularProfileKeypairToKeycard(keycardUid, self.tmpPassword, newPassword)
  else:
    error "invalid flow type", flowType=($self.tmpFlowType)

{.pop.}
