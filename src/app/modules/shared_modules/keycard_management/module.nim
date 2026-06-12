import nimqml, sugar, strutils, sequtils, chronicles, json, marshal, json_serialization

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
  ImportingKeyPair = "ImportingKeyPair" # imports a key pair form the seed phrase (provided or created by the app) to the Keycard
                                        # if the key pair is not already addded to the app, the flow adds it
  MigratingNonProfileKeypairToKeycard = "MigratingNonProfileKeypairToKeycard" # migrates a non-profile keypair to the keycard (only if the keypair is not already migrated)
  MigratingProfileKeypairToKeycard = "MigratingProfileKeypairToKeycard" # migrates a profile keypair to the keycard (only if the keypair is not already migrated)
  AddingKeyPairFromKeycard = "AddingKeyPairFromKeycard" # adds a new key pair from the keycard to the app (only if the key pair is not already added)
  StoppingKeycardForKeyPair = "StoppingKeycardForKeyPair" # stops using a Keycard for a non-profile key pair by moving it back into the app
  StoppingKeycardForProfileKeyPair = "StoppingKeycardForProfileKeyPair" # stops using a Keycard for the profile key pair by moving it back into the app
  ChangingKeycardPIN = "ChangingKeycardPIN" # changes the Keycard PIN
  ChangingKeycardPUK = "ChangingKeycardPUK" # sets or changes the Keycard PUK
  RenamingKeycard = "RenamingKeycard" # renames the Keycard (stores a new keycard metadata name)
  UnblockingKeycard = "UnblockingKeycard" # unblocks a Keycard with a blocked PIN by providing the PUK and a new PIN
  UnblockingKeycardWithRecoveryPhrase = "UnblockingKeycardWithRecoveryPhrase" # unblocks a Keycard by recovering it from the seed phrase and setting a new PIN
  AsyncLogin = "AsyncLogin" # exports the keys for the keycard's stored profile

type
  Module*[T: io_interface.DelegateInterface] = ref object of io_interface.AccessInterface
    delegate: T
    view: View
    viewVariant: QVariant
    controller: Controller
    tmpFlowType: FlowType
    tmpPassword: string
    tmpKeyUid: string
    tmpKeycardUid: string
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

proc setPathsFromMetadataAccountsJson*[T](self: Module[T], paths: var seq[string], metadataAccountsJson: string): string =
  try:
    let parsed = parseJson(metadataAccountsJson)
    if parsed.kind == JArray:
      for acc in parsed.elems:
        if acc.kind == JObject and acc.hasKey("path") and acc["path"].kind == JString:
          paths.add(acc["path"].getStr())
  except Exception as e:
    return "failed to parse keycard metadata accounts json: " & e.msg

proc createWalletAccountsJson*[T](self: Module[T], walletAccounts: seq[keycard_serviceV2.WalletAccountDto]): JsonNode =
  var walletsJson = newJArray()
  for acc in walletAccounts:
    walletsJson.add(%*{
      "path": acc.path,
      "address": acc.address,
      "publicKey": acc.publicKey,
    })
  return walletsJson

method onKeycardStateUpdated*[T](self: Module[T], kcEvent: KeycardEventDto) =
  self.view.setKeycardState($kcEvent.stateString)
  self.view.setKeycardStatusAvailable(kcEvent.keycardStatus.keyInitialized)
  self.view.setRemainingPinAttempts(kcEvent.keycardStatus.remainingAttemptsPIN)
  self.view.setRemainingPukAttempts(kcEvent.keycardStatus.remainingAttemptsPUK)
  self.view.setAvailableSlots(kcEvent.keycardInfo.availableSlots)
  self.view.setKeyUid(kcEvent.keycardInfo.keyUID)
  self.view.setKeycardUid(kcEvent.keycardInfo.instanceUID)
  self.view.setCardMetadataName(kcEvent.metadata.name)
  let jsonObj = self.createWalletAccountsJson(kcEvent.metadata.walletAccounts)
  self.view.setCardMetadataWalletAccountsJson($jsonObj)

method onKeycardGetMetadataFinished*[T](self: Module[T], metadata: CardMetadataDto, error: string) =
  if error.len > 0:
    error "keycard get metadata error", error=error
    self.view.keycardGetMetadataError(error)
    return
  self.view.setCardMetadataName(metadata.name)
  let jsonObj = self.createWalletAccountsJson(metadata.walletAccounts)
  self.view.setCardMetadataWalletAccountsJson($jsonObj)
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

method isKeyPairMigratedToKeycard*[T](self: Module[T], keyUid: string): bool =
  let keypair = self.controller.getKeypairByKeyUid(keyUid)
  if keypair.isNil or keypair.removed:
    return false
  return keypair.migratedToColdWallet()

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
  self.tmpAccountsData = @[]
  if metadataAccounts.len == 0:
    return true
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
  elif self.tmpFlowType == FlowType.StoppingKeycardForKeyPair:
    self.view.stopUsingKeycardForKeyPairError(err)
  elif self.tmpFlowType == FlowType.StoppingKeycardForProfileKeyPair:
    self.view.stopUsingKeycardForProfileKeyPairError(err)
  elif self.tmpFlowType == FlowType.ChangingKeycardPIN:
    self.view.keycardChangePinError(err)
  elif self.tmpFlowType == FlowType.ChangingKeycardPUK:
    self.view.keycardChangePukError(err)
  elif self.tmpFlowType == FlowType.RenamingKeycard:
    self.view.keycardRenameError(err)
  elif self.tmpFlowType == FlowType.UnblockingKeycard:
    self.view.keycardUnblockError(err)
  elif self.tmpFlowType == FlowType.UnblockingKeycardWithRecoveryPhrase:
    self.view.keycardUnblockError(err)
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
  if self.tmpFlowType == FlowType.MigratingProfileKeypairToKeycard:
    if not success:
      self.emitError("failed to convert profile keypair to keycard")
      return
    self.view.keycardMoveProfileKeyPairSuccess()
  elif self.tmpFlowType == FlowType.StoppingKeycardForProfileKeyPair:
    if not success:
      self.emitError("failed to convert profile keypair to the app")
      return
    self.view.stopUsingKeycardForProfileKeyPairSuccess()
  else:
    error "unexpected flow type on converting profile keypair finished", flowType=($self.tmpFlowType)

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
  return self.controller.addNewColdWalletStoredKeypair(self.tmpKeyUid, self.tmpKeypairName, self.tmpXpub,
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

method getKeyPairItemForKeyUid*[T](self: Module[T], keyUid: string): KeyPairItem =
  let keypair = self.controller.getKeypairByKeyUid(keyUid)
  if keypair.isNil or keypair.removed:
    return nil
  return keypairs.buildKeypairItem(keypair, areTestNetworksEnabled = false)

method remainingKeypairCapacity*[T](self: Module[T]): int =
  return self.controller.remainingKeypairCapacity()

method remainingAccountCapacity*[T](self: Module[T]): int =
  return self.controller.remainingAccountCapacity()

method startStopUsingKeycardForKeyPair*[T](self: Module[T], keyUid, seedPhrase, newPassword: string) =
  self.tmpFlowType = FlowType.StoppingKeycardForKeyPair
  self.tmpKeyUid = keyUid
  self.tmpSeedPhrase = seedPhrase
  self.tmpPassword = newPassword # it is hashed in the service
  self.controller.startStopUsingKeycardForKeyPair(keyUid, seedPhrase, newPassword)

method onStopUsingKeycardForKeyPairFinished*[T](self: Module[T], keyUid: string, success: bool) =
  if self.tmpFlowType != FlowType.StoppingKeycardForKeyPair:
    return
  if not success or keyUid != self.tmpKeyUid:
    self.emitError("failed to stop using Keycard for key pair")
    return
  self.view.stopUsingKeycardForKeyPairSuccess()

method startChangeKeycardPIN*[T](self: Module[T], currentPin, newPin: string) =
  self.tmpFlowType = FlowType.ChangingKeycardPIN
  let keyUid = self.view.getKeyUid()
  let keycardUid = self.view.getKeycardUid()
  self.controller.startChangeKeycardPIN(keyUid, currentPin, newPin, keycardUid)

method onChangeKeycardPINFinished*[T](self: Module[T], error: string) =
  if self.tmpFlowType != FlowType.ChangingKeycardPIN:
    return
  if error.len > 0:
    self.emitError("keycard change PIN error: " & error)
    return
  self.view.keycardChangePinSuccess()

method startChangeKeycardPUK*[T](self: Module[T], currentPin, newPuk: string) =
  self.tmpFlowType = FlowType.ChangingKeycardPUK
  let keyUid = self.view.getKeyUid()
  let keycardUid = self.view.getKeycardUid()
  self.controller.startChangeKeycardPUK(keyUid, currentPin, newPuk, keycardUid)

method onChangeKeycardPUKFinished*[T](self: Module[T], error: string) =
  if self.tmpFlowType != FlowType.ChangingKeycardPUK:
    return
  if error.len > 0:
    self.emitError("keycard change PUK error: " & error)
    return
  self.view.keycardChangePukSuccess()

method startRenameKeycard*[T](self: Module[T], currentPin, newName, metadataAccountsJson: string) =
  self.tmpFlowType = FlowType.RenamingKeycard
  var paths: seq[string] = @[]
  let err = self.setPathsFromMetadataAccountsJson(paths, metadataAccountsJson)
  if err.len > 0:
    self.emitError(err)
    return
  self.controller.startRenameKeycard(currentPin, newName, paths)

method onRenameKeycardFinished*[T](self: Module[T], error: string) =
  if self.tmpFlowType != FlowType.RenamingKeycard:
    return
  if error.len > 0:
    self.emitError("keycard rename error: " & error)
    return
  self.view.keycardRenameSuccess()

method startUnblockKeycardUsingPuk*[T](self: Module[T], newPin, puk: string) =
  self.tmpFlowType = FlowType.UnblockingKeycard
  let keyUid = self.view.getKeyUid()
  let keycardUid = self.view.getKeycardUid()
  self.controller.startUnblockKeycardUsingPuk(keyUid, puk, newPin, keycardUid)

method onUnblockKeycardFinished*[T](self: Module[T], error: string) =
  if self.tmpFlowType != FlowType.UnblockingKeycard:
    return
  if error.len > 0:
    self.emitError("keycard unblock error: " & error)
    return
  self.view.keycardUnblockSuccess()

method startUnblockKeycardUsingRecoveryPhrase*[T](self: Module[T], newPin: string, seedPhrase: string, metadataName: string,
    metadataAccountsJson: string) =
  self.tmpFlowType = FlowType.UnblockingKeycardWithRecoveryPhrase
  self.tmpKeycardUid = self.view.getKeycardUid()
  var paths: seq[string] = @[]
  let err = self.setPathsFromMetadataAccountsJson(paths, metadataAccountsJson)
  if err.len > 0:
    self.emitError(err)
    return
  let puk = keycard_serviceV2.generateRandomPUK()
  self.controller.startRecover(newPin, puk, seedPhrase, metadataName, paths, self.tmpKeycardUid)

method onKeycardRecoverFinished*[T](self: Module[T], error: string) =
  if self.tmpFlowType != FlowType.UnblockingKeycardWithRecoveryPhrase:
    return
  if error.len > 0:
    self.emitError("keycard recover error: " & error)
    return
  ## #########################################################
  ## TODO: remove the part below once we remove the keycard management on the status-go side
  ## For now, we just update the keycard uid in the db and don't care (listen for signal) about the result of that operation
  let newKeycardUid = self.view.getKeycardUid()
  if self.tmpKeycardUid.len > 0 and newKeycardUid.len > 0 and self.tmpKeycardUid != newKeycardUid:
    self.controller.updateKeycardUid(self.tmpKeycardUid, newKeycardUid)
  ## #########################################################
  self.view.keycardUnblockSuccess()

method startAsyncLogin*[T](self: Module[T], keyUid, pin: string, generateXPub: bool) =
  self.tmpFlowType = FlowType.AsyncLogin
  self.tmpKeyUid = keyUid
  var xPubPath = ""
  if generateXPub:
    xPubPath = PATH_WALLET_XPUB
  self.controller.startAsyncLogin(keyUid, pin, xPubPath)

method onKeycardAsyncLoginFinished*[T](self: Module[T], exportedKeys: KeycardExportedKeysDto, error: string) =
  if self.tmpFlowType != FlowType.AsyncLogin:
    return
  if error.len > 0:
    self.view.keycardAsyncLoginError(error)
    return
  try:
    var exportedKeysCopy = exportedKeys
    # if extended public key is generated, means the keycard login action is used to create a new profile, and we need to derive default wallet account
    if exportedKeysCopy.extendedPublicKey.xpub.len > 0:
      let defaultWalletAccountsJson = $(%* [{"path": PATH_DEFAULT_WALLET}])
      if not self.prepareAccountsData(exportedKeysCopy.extendedPublicKey.xpub, defaultWalletAccountsJson) or self.tmpAccountsData.len == 0:
        self.emitError("failed to prepare accounts data")
        return
      # We don't need to set master address, walletRootAddress and eip1581Address, cause they are not needed anymore, we should remove those from the code
      exportedKeysCopy.walletKey = KeyDetailsV2(
        address: self.tmpAccountsData[0].address,
        publicKey: self.tmpAccountsData[0].publicKey,
      )

    let exportedKeysJsonObj = parseJson($$exportedKeysCopy)

    let payload = %*{
      "flow": "onboarding-login-with-keycard",
      "keyUid": self.tmpKeyUid,
      "keycardUid": self.view.getKeycardUid(),
      "exportedKeys": exportedKeysJsonObj
    }
    self.view.keycardAsyncLoginSuccess($payload)
  except Exception as e:
    error "failed to parse exported keys", err=e.msg
    self.view.keycardAsyncLoginError(e.msg)

method startStopUsingKeycardForProfileKeyPair*[T](self: Module[T], seedPhrase, newPassword: string) =
  self.tmpFlowType = FlowType.StoppingKeycardForProfileKeyPair
  self.tmpSeedPhrase = seedPhrase
  self.tmpPassword = newPassword # don't hash it here, cause it's hashed in the service
  let acc = self.controller.createAccountFromMnemonic(seedPhrase, includeEncryption = true)
  let currentPassword = acc.derivedAccounts.encryption.publicKey
  if currentPassword.len == 0:
    self.emitError("failed to derive encryption public key from seed phrase")
    return
  self.controller.setStoreToKeychainValueNotNow()
  self.controller.convertKeycardProfileKeypairToRegular(seedPhrase, currentPassword, newPassword)

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

  # additional check to protect against adding a key pair which is already in the db, in case `startAddingKeyPairToStatusFromKeycard` is not called from the DetailsView
  if self.isKnownKeyUid(self.tmpKeyUid):
    self.emitError("key pair already exists in db, cannot be added, keyUid: " & self.tmpKeyUid)
    return

  self.tmpXpub = xpub

  if not self.prepareAccountsData(self.tmpXpub, self.tmpMetadataAccountsJson):
    self.emitError("failed to prepare accounts data")
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
    if not self.isKnownKeyUid(self.tmpKeyUid):
      let err = self.addNewKeycardKeypair()
      if err.len > 0:
        self.emitError("failed to add new keycard stored keypair: " & err)
        return
      self.saveKeypairToKeycard() # this is just to add keycard to db and remove keystore files
    elif not self.isKeyPairMigratedToKeycard(self.tmpKeyUid):
      self.emitError("key pair is not migrated to keycard, cannot be imported to keycard, keyUid: " & self.tmpKeyUid)
      return
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
