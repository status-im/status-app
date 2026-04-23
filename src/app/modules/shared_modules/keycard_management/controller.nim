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
  let (keyUID, err) = self.accountsService.validateMnemonic(seedPhrase)
  if err.len > 0:
    return ""
  return keyUID

proc getKeypairByKeyUid*(self: Controller, keyUid: string): KeypairDto =
  return self.walletAccountService.getKeypairByKeyUid(keyUid)

proc addNewKeycardStoredKeypair*(self: Controller, keyUid, keypairName, xpub, coldWallet: string, accounts: seq[wallet_account_service.WalletAccountDto]): string =
  return self.walletAccountService.addNewKeycardStoredKeypairNew(keyUid, keypairName, xpub, coldWallet, rootWalletMasterKey="", accounts)

proc addKeycardOrAccounts*(self: Controller, keyPair: KeycardDto, password: string) =
  self.walletAccountService.addKeycardOrAccountsAsync(keyPair, password)

proc deriveAccountsPublicInfoFromExtendedPublicKeyForPaths*(self: Controller, extendedPublicKey: string, paths: seq[string]): DerivedAccounts =
  return self.accountsService.deriveAccountsPublicInfoFromExtendedPublicKeyForPaths(extendedPublicKey, paths)

proc deriveExtendedPublicKeyAtPath*(self: Controller, mnemonic: string, passphrase: string, path: string): string =
  return self.accountsService.deriveExtendedPublicKeyAtPath(mnemonic, passphrase, path)

proc generateMnemonic*(self: Controller): string =
  return self.walletAccountService.getRandomMnemonic()

proc getKeypairs*(self: Controller): seq[wallet_account_service.KeypairDto] =
  return self.walletAccountService.getKeypairs()

proc updateKeypairExtendedPublicKey*(self: Controller, keyUid, extendedPublicKey, coldWalletType: string): string =
  return self.walletAccountService.updateKeypairExtendedPublicKey(keyUid, extendedPublicKey, coldWalletType)

proc isMnemonicBackedUp*(self: Controller): bool =
  return self.privacyService.isMnemonicBackedUp()

proc getMnemonic*(self: Controller): string =
  return self.privacyService.getMnemonic()

proc createAccountFromMnemonic*(self: Controller, mnemonic: string, includeEncryption: bool): GeneratedAccountDto =
  return self.accountsService.createAccountFromMnemonic(mnemonic, includeEncryption = includeEncryption)

proc convertRegularProfileKeypairToKeycard*(self: Controller, keycardUid, currentPassword, newPassword: string) =
  self.accountsService.convertRegularProfileKeypairToKeycard(keycardUid, currentPassword, newPassword)

proc convertKeycardProfileKeypairToRegular*(self: Controller, mnemonic, currentPassword, newPassword: string) =
  self.accountsService.convertKeycardProfileKeypairToRegular(mnemonic, currentPassword, newPassword)

proc setStoreToKeychainValueNotNow*(self: Controller) =
  singletonInstance.localAccountSettings.setStoreToKeychainValue(LS_VALUE_NOT_NOW)

proc startStopUsingKeycardForKeyPair*(self: Controller, keyUid, seedPhrase, newPassword: string) =
  self.walletAccountService.migrateNonProfileKeycardKeypairToAppAsync(keyUid, seedPhrase, newPassword, doPasswordHashing = true)

proc startChangeKeycardPIN*(self: Controller, keyUid, currentPin, newPin, keycardUid: string) =
  self.keycardServiceV2.asyncChangeKeycardPIN(keyUid, currentPin, newPin, keycardUid)

proc remainingKeypairCapacity*(self: Controller): int =
  return self.walletAccountService.remainingKeypairCapacity()

proc remainingAccountCapacity*(self: Controller): int =
  return self.walletAccountService.remainingAccountCapacity()