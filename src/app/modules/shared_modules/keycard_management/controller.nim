import chronicles
import uuids
import io_interface

import app/core/eventemitter
import app/global/global_singleton
import app_service/service/keycardV2/service as keycard_serviceV2
import app_service/service/accounts/service as accounts_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/privacy/service as privacy_service

logScope:
  topics = "keycard-management-module-controller"

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    connectionIds: seq[UUID]
    keycardServiceV2: keycard_serviceV2.Service
    accountsService: accounts_service.Service
    walletAccountService: wallet_account_service.Service
    privacyService: privacy_service.Service

proc newController*(delegate: io_interface.AccessInterface,
  events: EventEmitter,
  keycardServiceV2: keycard_serviceV2.Service,
  accountsService: accounts_service.Service,
  walletAccountService: wallet_account_service.Service,
  privacyService: privacy_service.Service):
  Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.keycardServiceV2 = keycardServiceV2
  result.accountsService = accountsService
  result.walletAccountService = walletAccountService
  result.privacyService = privacyService

## Forward declarations:
proc serviceApplicable[T](service: T): bool

proc delete*(self: Controller) =
  for id in self.connectionIds:
    self.events.disconnect(id)

proc init*(self: Controller) =
  var handlerId = self.events.onWithUUID(SIGNAL_KEYCARD_STATE_UPDATED) do(e: Args):
    let args = KeycardEventArg(e)
    self.delegate.onKeycardStateUpdated(args.keycardEvent)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_KEYCARD_GET_KEYCARD_METADATA_FINISHED) do(e: Args):
    let args = KeycardGetKeycardMetadataArgs(e)
    self.delegate.onKeycardGetMetadataFinished(args.metadata, args.error)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_KEYCARD_FACTORY_RESET_KEYCARD_FINISHED) do(e: Args):
    let args = KeycardErrorArg(e)
    self.delegate.onKeycardFactoryResetFinished(args.error)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_KEYCARD_LOAD_FINISHED) do(e: Args):
    let args = KeycardErrorArg(e)
    self.delegate.onKeycardLoadSeedPhraseFinished(args.error)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_CONVERTING_PROFILE_KEYPAIR) do(e: Args):
    let args = ResultArgs(e)
    self.delegate.onConvertingProfileKeypairFinished(args.success)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_KEYCARD_EXPORT_EXTENDED_PUBLIC_KEYS_FINISHED) do(e: Args):
    let args = KeycardExportedExtendedPublicKeyArgs(e)
    self.delegate.onKeycardExportExtendedPublicKeyFinished(args.exportedExtendedPublicKey.xpub, args.error)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_ALL_KEYCARDS_DELETED) do(e: Args):
    let args = KeycardArgs(e)
    self.delegate.onStopUsingKeycardForKeyPairFinished(args.keycard.keyUid, args.success)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_KEYCARD_CHANGE_PIN_FINISHED) do(e: Args):
    let args = KeycardErrorArg(e)
    self.delegate.onChangeKeycardPINFinished(args.error)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_KEYCARD_CHANGE_PUK_FINISHED) do(e: Args):
    let args = KeycardErrorArg(e)
    self.delegate.onChangeKeycardPUKFinished(args.error)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_KEYCARD_STORE_KEYCARD_METADATA_FINISHED) do(e: Args):
    let args = KeycardErrorArg(e)
    self.delegate.onRenameKeycardFinished(args.error)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_KEYCARD_UNBLOCK_FINISHED) do(e: Args):
    let args = KeycardErrorArg(e)
    self.delegate.onUnblockKeycardFinished(args.error)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_KEYCARD_RECOVER_FINISHED) do(e: Args):
    let args = KeycardLoginArgs(e)
    self.delegate.onKeycardRecoverFinished(args.error)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_KEYCARD_LOGIN_FINISHED) do(e: Args):
    let args = KeycardLoginArgs(e)
    self.delegate.onKeycardAsyncLoginFinished(args.exportedKeys, args.error)
  self.connectionIds.add(handlerId)

proc startGetMetadata*(self: Controller, pin: string) =
  self.keycardServiceV2.asyncGetKeycardMetadata(pin)

proc startFactoryReset*(self: Controller, keycardUid: string) =
  self.keycardServiceV2.asyncFactoryResetKeycard(keycardUid)

proc startLoadSeedPhrase*(self: Controller, pin: string, puk: string, seedPhrase: string, metadataName: string,
    metadataPaths: seq[string]) =
  self.keycardServiceV2.asyncLoadSeedPhrase(pin, puk, seedPhrase, metadataName, metadataPaths)

proc startExportExtendedPublicKey*(self: Controller, keyUid: string, path: string, pin: string) =
  self.keycardServiceV2.asyncExportExtendedPublicKey(keyUid, path, pin)

proc stopKeycardAction*(self: Controller) =
  self.keycardServiceV2.asyncStop()

proc getKeyUidForSeedPhrase*(self: Controller, seedPhrase: string): string =
  if not serviceApplicable(self.accountsService):
    return
  let (keyUID, err) = self.accountsService.validateMnemonic(seedPhrase)
  if err.len > 0:
    return ""
  return keyUID

proc getKeypairByKeyUid*(self: Controller, keyUid: string): KeypairDto =
  if not serviceApplicable(self.walletAccountService):
    return
  return self.walletAccountService.getKeypairByKeyUid(keyUid)

proc addNewColdWalletStoredKeypair*(self: Controller, keyUid, keypairName, xpub, coldWallet: string, accounts: seq[wallet_account_service.WalletAccountDto]): string =
  if not serviceApplicable(self.walletAccountService):
    return
  return self.walletAccountService.addNewColdWalletStoredKeypair(keyUid, keypairName, xpub, coldWallet,
    rootWalletMasterKey = "", accounts)

proc addKeycardOrAccounts*(self: Controller, keyPair: KeycardDto, password: string) =
  # TODO: re-implement when integrating new keycard approach
  discard

proc deriveAccountsPublicInfoFromExtendedPublicKeyForPaths*(self: Controller, extendedPublicKey: string, paths: seq[string]): DerivedAccounts =
  if not serviceApplicable(self.accountsService):
    return
  return self.accountsService.deriveAccountsPublicInfoFromExtendedPublicKeyForPaths(extendedPublicKey, paths)

proc deriveExtendedPublicKeyAtPath*(self: Controller, mnemonic: string, passphrase: string, path: string): string =
  if not serviceApplicable(self.accountsService):
    return
  return self.accountsService.deriveExtendedPublicKeyAtPath(mnemonic, passphrase, path)

proc generateMnemonic*(self: Controller): string =
  if not serviceApplicable(self.accountsService):
    return
  return self.accountsService.getRandomMnemonic()

proc getKeypairs*(self: Controller): seq[wallet_account_service.KeypairDto] =
  if not serviceApplicable(self.walletAccountService):
    return
  return self.walletAccountService.getKeypairs()

proc updateKeypairExtendedPublicKey*(self: Controller, keyUid, extendedPublicKey, coldWalletType: string): string =
  if not serviceApplicable(self.walletAccountService):
    return
  return self.walletAccountService.updateKeypairExtendedPublicKey(keyUid, extendedPublicKey, coldWalletType)

proc isMnemonicBackedUp*(self: Controller): bool =
  if not serviceApplicable(self.privacyService):
    return
  return self.privacyService.isMnemonicBackedUp()

proc getMnemonic*(self: Controller): string =
  if not serviceApplicable(self.privacyService):
    return
  return self.privacyService.getMnemonic()

proc createAccountFromMnemonic*(self: Controller, mnemonic: string, includeEncryption: bool): GeneratedAccountDto =
  if not serviceApplicable(self.accountsService):
    return
  return self.accountsService.createAccountFromMnemonic(mnemonic, includeEncryption = includeEncryption)

proc convertRegularProfileKeypairToKeycard*(self: Controller, keycardUid, currentPassword, newPassword: string) =
  if not serviceApplicable(self.accountsService):
    return
  self.accountsService.convertRegularProfileKeypairToKeycard(keycardUid, currentPassword, newPassword)

proc convertKeycardProfileKeypairToRegular*(self: Controller, mnemonic, currentPassword, newPassword: string) =
  if not serviceApplicable(self.accountsService):
    return
  self.accountsService.convertKeycardProfileKeypairToRegular(mnemonic, currentPassword, newPassword)

proc setStoreToKeychainValueNotNow*(self: Controller) =
  singletonInstance.localAccountSettings.setStoreToKeychainValue(LS_VALUE_NOT_NOW)

proc startStopUsingKeycardForKeyPair*(self: Controller, keyUid, seedPhrase, newPassword: string) =
  if not serviceApplicable(self.walletAccountService):
    return
  self.walletAccountService.migrateNonProfileKeycardKeypairToAppAsync(keyUid, seedPhrase, newPassword, doPasswordHashing = true)

proc startChangeKeycardPIN*(self: Controller, keyUid, currentPin, newPin, keycardUid: string) =
  self.keycardServiceV2.asyncChangeKeycardPIN(keyUid, currentPin, newPin, keycardUid)

proc startChangeKeycardPUK*(self: Controller, keyUid, currentPin, newPuk, keycardUid: string) =
  self.keycardServiceV2.asyncChangeKeycardPUK(keyUid, currentPin, newPuk, keycardUid)

proc startRenameKeycard*(self: Controller, pin, name: string, paths: seq[string]) =
  self.keycardServiceV2.asyncStoreKeycardMetadata(pin, name, paths)

proc startUnblockKeycardUsingPuk*(self: Controller, keyUid, puk, newPin, keycardUid: string) =
  self.keycardServiceV2.asyncUnblockUsingPUK(keyUid, puk, newPin, keycardUid)

proc startRecover*(self: Controller, pin, puk, mnemonic, metadataName: string, metadataPaths: seq[string], keycardUid: string) =
  self.keycardServiceV2.asyncRecover(pin, puk, mnemonic, metadataName, metadataPaths, keycardUid)

proc startAsyncLogin*(self: Controller, keyUid, pin, xPubPath: string) =
  self.keycardServiceV2.asyncLogin(keyUid, pin, xPubPath)

proc updateKeycardUid*(self: Controller, oldKeycardUid, newKeycardUid: string) =
  # TODO: re-implement when integrating new keycard approach
  discard

proc remainingKeypairCapacity*(self: Controller): int =
  if not serviceApplicable(self.walletAccountService):
    return
  return self.walletAccountService.remainingKeypairCapacity()

proc remainingAccountCapacity*(self: Controller): int =
  if not serviceApplicable(self.walletAccountService):
    return
  return self.walletAccountService.remainingAccountCapacity()

# Keep this function at the end of the file.
# There's a bug in Nim: https://github.com/nim-lang/Nim/issues/23002
# that blocks us from enabling back the warning pragma.

{.warning[UnreachableCode]: off.}
proc serviceApplicable[T](service: T): bool =
  if not service.isNil:
    return true
  when (service is keycard_serviceV2.Service):
    error "KeycardServiceV2 is mandatory for shared keycard_management module"
    return
  var serviceName = ""
  when service is wallet_account_service.Service:
    serviceName = "WalletAccountService"
  when service is privacy_service.Service:
    serviceName = "PrivacyService"
  when service is accounts_service.Service:
    serviceName = "AccountsService"
  debug "service not set in shared keycard_management module - call short-circuits",
    service = serviceName