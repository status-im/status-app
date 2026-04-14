import chronicles
import uuids
import io_interface

import app/core/eventemitter
import app_service/service/keycardV2/service as keycard_serviceV2
import app_service/service/accounts/service as accounts_service
import app_service/service/wallet_account/service as wallet_account_service

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

proc newController*(delegate: io_interface.AccessInterface,
  events: EventEmitter,
  keycardServiceV2: keycard_serviceV2.Service,
  accountsService: accounts_service.Service,
  walletAccountService: wallet_account_service.Service):
  Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.keycardServiceV2 = keycardServiceV2
  result.accountsService = accountsService
  result.walletAccountService = walletAccountService

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

proc startGetMetadata*(self: Controller, pin: string) =
  self.keycardServiceV2.asyncGetKeycardMetadata(pin)

proc startFactoryReset*(self: Controller, keycardUid: string) =
  self.keycardServiceV2.asyncFactoryResetKeycard(keycardUid)

proc startLoadSeedPhrase*(self: Controller, pin: string, puk: string, seedPhrase: string, metadataName: string,
    metadataPaths: seq[string]) =
  self.keycardServiceV2.asyncLoadSeedPhrase(pin, puk, seedPhrase, metadataName, metadataPaths)

proc stopKeycardAction*(self: Controller) =
  self.keycardServiceV2.asyncStop()

proc getKeyUidForSeedPhrase*(self: Controller, seedPhrase: string): string =
  let (keyUID, err) = self.accountsService.validateMnemonic(seedPhrase)
  if err.len > 0:
    return ""
  return keyUID

proc getKeypairByKeyUid*(self: Controller, keyUid: string): KeypairDto =
  return self.walletAccountService.getKeypairByKeyUid(keyUid)

proc addNewKeycardStoredKeypair*(self: Controller, keyUid, keypairName, xpub, coldWallet: string, accounts: seq[wallet_account_service.WalletAccountDto]): bool =
  let err = self.walletAccountService.addNewKeycardStoredKeypairNew(keyUid, keypairName, xpub, coldWallet, rootWalletMasterKey="", accounts)
  if err.len > 0:
    info "adding new keycard stored keypair failed", keypairName=keypairName, keyUid=keyUid
    return false
  return true

proc addKeycardOrAccounts*(self: Controller, keyPair: KeycardDto, password: string) =
  self.walletAccountService.addKeycardOrAccountsAsync(keyPair, password)

proc deriveAccountsPublicInfoFromExtendedPublicKeyForPaths*(self: Controller, extendedPublicKey: string, paths: seq[string]): DerivedAccounts =
  return self.accountsService.deriveAccountsPublicInfoFromExtendedPublicKeyForPaths(extendedPublicKey, paths)

proc deriveExtendedPublicKeyAtPath*(self: Controller, mnemonic: string, passphrase: string, path: string): string =
  return self.accountsService.deriveExtendedPublicKeyAtPath(mnemonic, passphrase, path)

proc generateMnemonic*(self: Controller): string =
  return self.walletAccountService.getRandomMnemonic()