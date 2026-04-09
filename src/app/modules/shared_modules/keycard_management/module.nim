import nimqml, sugar, strutils, chronicles, json, json_serialization, uuids

import io_interface
import view, controller
import app/core/eventemitter

import app_service/common/account_constants
import app_service/service/keycardV2/service as keycard_serviceV2
import app_service/service/accounts/service as accounts_service
import app_service/service/wallet_account/service as wallet_account_service

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

type
  Module*[T: io_interface.DelegateInterface] = ref object of io_interface.AccessInterface
    delegate: T
    view: View
    viewVariant: QVariant
    controller: Controller
    tmpKeyUid: string
    tmpKeypairName: string
    tmpXpub: string
    tmpAccountsData: seq[AccountData]

proc newModule*[T](delegate: T,
  events: EventEmitter,
  keycardServiceV2: keycard_serviceV2.Service,
  accountsService: accounts_service.Service,
  walletAccountService: wallet_account_service.Service):
  Module[T] =
  result = Module[T]()
  result.delegate = delegate
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, events, keycardServiceV2, accountsService, walletAccountService)
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

  let relativePaths = self.tmpAccountsData.map(a => a.path.replace(PATH_WALLET_XPUB&"/", ""))

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

method startLoadSeedPhrase*[T](self: Module[T], pin: string, seedPhrase: string, metadataName: string, metadataAccounts: string) =
  self.tmpKeypairName = metadataName
  self.tmpKeyUid = self.controller.getKeyUidForSeedPhrase(seedPhrase)
  if self.tmpKeyUid.len == 0:
    error "failed to get key uid for seed phrase"
    self.view.keycardImportKeyPairError("failed to get key uid for seed phrase")
    return

  self.tmpXpub = self.controller.deriveExtendedPublicKeyAtPath(seedPhrase, passphrase = "", PATH_WALLET_XPUB)
  if self.tmpXpub.len == 0:
    error "failed to derive extended public key"
    self.view.keycardImportKeyPairError("failed to derive extended public key")
    return

  if not self.prepareAccountsData(self.tmpXpub, metadataAccounts):
    error "failed to prepare accounts data"
    self.view.keycardImportKeyPairError("failed to prepare accounts data")
    return

  let puk = keycard_serviceV2.generateRandomPUK()
  let paths = self.tmpAccountsData.map(a => a.path)
  self.controller.startLoadSeedPhrase(pin, puk, seedPhrase, metadataName, paths)

proc saveKeypairToKeycard*[T](self: Module[T]): bool =
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

  let success = self.controller.addNewKeycardStoredKeypair(self.tmpKeyUid, self.tmpKeypairName, self.tmpXpub,
    wallet_account_service.ColdWalletTypeStatusKeycard, walletAccounts)
  if not success:
    error "failed to add new keycard stored keypair"
    return false

  ## #########################################################
  ## TODO: remove the part below once we remove the keycard management on the status-go side
  ## For now, we just add a new keycard and don't care (listen for signal) about the result of that operation
  let keyPair = KeycardDto(
    keycardUid: $genUUID(),
    keyUid: self.tmpKeyUid,
    keycardName: self.tmpKeypairName,
    keycardLocked: false,
    accountsAddresses: self.tmpAccountsData.map(a => a.address),
  )
  self.controller.addKeycardOrAccounts(keyPair, password = "")
  ## #########################################################
  return true

method onKeycardLoadSeedPhraseFinished*[T](self: Module[T], error: string) =
  if error.len > 0:
    error "keycard load key pair error", error=error
    self.view.keycardImportKeyPairError(error)
    return

  if not self.isKnownKeyUid(self.tmpKeyUid) and
    not self.saveKeypairToKeycard():
      error "added to keycard, but failed to add keypair to app"
      self.view.keycardImportKeyPairError("added to keycard, but failed to add keypair to app")
      return

  self.view.keycardImportKeyPairSuccess()

{.pop.}
