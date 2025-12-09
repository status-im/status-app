import chronicles
import io_interface
import uuids

import app/core/eventemitter
import app/core/signals/types
import app/global/app_signals
import app_service/service/general/service as general_service
import app_service/service/accounts/service as accounts_service
import app_service/service/accounts/dto/image_crop_rectangle
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/devices/service as devices_service
import app_service/service/keycardV2/service as keycard_serviceV2
import app_service/common/utils
from app_service/service/keycardV2/dto import KeycardExportedKeysDto

logScope:
  topics = "onboarding-controller"

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    connectionIds: seq[UUID]
    generalService: general_service.Service
    accountsService: accounts_service.Service
    walletAccountService: wallet_account_service.Service
    devicesService: devices_service.Service
    keycardServiceV2: keycard_serviceV2.Service

proc newController*(
    delegate: io_interface.AccessInterface,
    events: EventEmitter,
    generalService: general_service.Service,
    accountsService: accounts_service.Service,
    walletAccountService: wallet_account_service.Service,
    devicesService: devices_service.Service,
    keycardServiceV2: keycard_serviceV2.Service,
  ):
  Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.generalService = generalService
  result.accountsService = accountsService
  result.walletAccountService = walletAccountService
  result.devicesService = devicesService
  result.keycardServiceV2 = keycardServiceV2

proc disconnect*(self: Controller) =
  for id in self.connectionIds:
    self.events.disconnect(id)

proc delete*(self: Controller) =
  self.disconnect()

proc init*(self: Controller) =
  var handlerId = self.events.onWithUUID(SignalType.NodeLogin.event) do(e:Args):
    let signal = NodeSignal(e)
    self.delegate.onNodeLogin(signal.error, signal.account, signal.settings)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_LOCAL_PAIRING_STATUS_UPDATE) do(e: Args):
    let args = LocalPairingStatus(e)
    if args.pairingType != PairingType.AppSync:
      return
    self.delegate.onLocalPairingStatusUpdate(args)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_KEYCARD_STATE_UPDATED) do(e: Args):
    let args = KeycardEventArg(e)
    self.delegate.onKeycardStateUpdated(args.keycardEvent)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_KEYCARD_SET_PIN_FAILURE) do(e: Args):
    let args = KeycardErrorArg(e)
    self.delegate.onKeycardSetPinFailure(args.error)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_KEYCARD_AUTHORIZE_FINISHED) do(e: Args):
    let args = KeycardAuthorizeEvent(e)
    self.delegate.onKeycardAuthorizeFinished(args.error, args.authorized)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_KEYCARD_LOAD_MNEMONIC_FAILURE) do(e: Args):
    let args = KeycardErrorArg(e)
    self.delegate.onKeycardLoadMnemonicFailure(args.error)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_KEYCARD_LOAD_MNEMONIC_SUCCESS) do(e: Args):
    let args = KeycardKeyUIDArg(e)
    self.delegate.onKeycardLoadMnemonicSuccess(args.keyUID)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_KEYCARD_EXPORT_RESTORE_KEYS_FAILURE) do(e: Args):
    let args = KeycardErrorArg(e)
    self.delegate.onKeycardExportRestoreKeysFailure(args.error)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_KEYCARD_EXPORT_RESTORE_KEYS_SUCCESS) do(e: Args):
    let args = KeycardExportedKeysArg(e)
    self.delegate.onKeycardExportRestoreKeysSuccess(args.exportedKeys)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_KEYCARD_EXPORT_LOGIN_KEYS_FAILURE) do(e: Args):
    let args = KeycardErrorArg(e)
    self.delegate.onKeycardExportLoginKeysFailure(args.error)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_KEYCARD_EXPORT_LOGIN_KEYS_SUCCESS) do(e: Args):
    let args = KeycardExportedKeysArg(e)
    self.delegate.onKeycardExportLoginKeysSuccess(args.exportedKeys)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_LOGIN_ERROR) do(e: Args):
    let args = LoginErrorArgs(e)
    self.delegate.onAccountLoginError(args.error)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SignalType.DBReEncryptionStarted.event) do(e: Args):
    debug "reencryption process started"
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SignalType.DBReEncryptionFinished.event) do(e: Args):
    debug "reencryption process finished"
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_CONVERTING_PROFILE_KEYPAIR) do(e: Args):
    let args = ResultArgs(e)
    self.delegate.onKeycardAccountConverted(args.success)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_MAIN_LOADED) do(e: Args):
    self.delegate.onMainLoaded()
  self.connectionIds.add(handlerId)

proc initialize*(self: Controller, pin: string) =
  let puk = keycard_serviceV2.generateRandomPUK()
  self.keycardServiceV2.asyncInitialize(pin, puk)

proc authorize*(self: Controller, pin: string) =
  self.keycardServiceV2.asyncAuthorize(pin)

proc getPasswordStrengthScore*(self: Controller, password, userName: string): int =
  return self.generalService.getPasswordStrengthScore(password, userName)

proc validMnemonic*(self: Controller, mnemonic: string): bool =
  let (_, err) = self.accountsService.validateMnemonic(mnemonic)
  return err.len == 0

proc isMnemonicDuplicate*(self: Controller, mnemonic: string): bool =
  let (keyUID, err) = self.accountsService.validateMnemonic(mnemonic)
  return self.accountsService.openedAccountsContainsKeyUid(keyUID)

proc loadMnemonic*(self: Controller, mnemonic: string) =
  self.keycardServiceV2.asyncLoadMnemonic(mnemonic)

proc validateLocalPairingConnectionString*(self: Controller, connectionString: string): bool =
  let err = self.devicesService.validateConnectionString(connectionString)
  return err.len == 0

proc inputConnectionStringForBootstrapping*(self: Controller, connectionString: string) =
  self.devicesService.inputConnectionStringForBootstrapping(connectionString)

proc createAccountAndLogin*(self: Controller, password: string, thirdpartyServicesEnabled: bool): string =
  return self.accountsService.createAccountAndLogin(
    password,
    displayName = "",
    imagePath = "",
    ImageCropRectangle(),
    thirdpartyServicesEnabled,
  )

proc restoreAccountAndLogin*(self: Controller, password, mnemonic: string, 
  keycardInstanceUID: string, thirdpartyServicesEnabled: bool): string =
  return self.accountsService.importAccountAndLogin(
    mnemonic,
    password,
    displayName = "",
    imagePath = "",
    ImageCropRectangle(),
    keycardInstanceUID,
    thirdpartyServicesEnabled,
  )

proc restoreKeycardAccountAndLogin*(self: Controller, keyUid, instanceUid: string, 
  keycardKeys: KeycardExportedKeysDto, thirdpartyServicesEnabled: bool): string =
  return self.accountsService.restoreKeycardAccountAndLoginV2(
    keyUid,
    instanceUid,
    keycardKeys,
    thirdpartyServicesEnabled,
  )

proc setLoggedInAccount*(self: Controller, account: AccountDto) =
  self.accountsService.setLoggedInAccount(account)
  self.accountsService.updateLoggedInAccount(account.name, account.images)

proc loginLocalPairingAccount*(self: Controller, account: AccountDto, password, chatkey: string) =
  self.accountsService.login(
    account,
    password,
    chatPrivateKey = chatKey
  )

proc finishPairingThroughSeedPhraseProcess*(self: Controller, installationId: string) =
  self.devicesService.finishPairingThroughSeedPhraseProcess(installationId)

proc stopKeycardService*(self: Controller) =
  self.keycardServiceV2.stop()

proc stopKeycardServiceAsync*(self: Controller) =
  self.keycardServiceV2.asyncStop()

proc generateMnemonic*(self: Controller, length: int): string =
  return self.keycardServiceV2.generateMnemonic(length)

proc exportRecoverKeysFromKeycard*(self: Controller) =
  self.keycardServiceV2.asyncExportRecoverKeys()

proc exportLoginKeysFromKeycard*(self: Controller) =
  self.keycardServiceV2.asyncExportLoginKeys()

proc getOpenedAccounts*(self: Controller): seq[AccountDto] =
  return self.accountsService.openedAccounts()

proc getAccountByKeyUid*(self: Controller, keyUid: string): AccountDto =
  return self.accountsService.getAccountByKeyUid(keyUid)

proc login*(
    self: Controller,
    account: AccountDto,
    password: string,
    keycard: bool = false,
    publicEncryptionKey: string = "",
    privateWhisperKey: string = "",
    mnemonic: string = "",
    keycardReplacement: bool = false,
  ) =
  var passwordHash, chatPrivateKey = ""

  if not keycard:
    passwordHash = hashPassword(password)
  else:
    passwordHash = publicEncryptionKey
    chatPrivateKey = privateWhisperKey

  self.accountsService.login(
    account,
    passwordHash,
    chatPrivateKey,
    mnemonic,
  )

proc getKeypairByKeyUidFromDb*(self: Controller, keyUid: string): wallet_account_service.KeypairDto =
  return self.walletAccountService.getKeypairByKeyUidFromDb(keyUid)

proc addKeycardOrAccounts*(self: Controller, keyPair: KeycardDto, password: string) =
  self.walletAccountService.addKeycardOrAccountsAsync(keyPair, password)

proc getMetadata*(self: Controller): keycard_serviceV2.CardMetadataDto =
  return self.keycardServiceV2.getMetadata()

proc startKeycardFactoryReset*(self: Controller) =
  self.keycardServiceV2.asyncFactoryReset()

proc storeMetadata*(self: Controller, name: string, paths: seq[string]) =
  self.keycardServiceV2.storeMetadata(name, paths)

proc storeMetadataAsync*(self: Controller, name: string, paths: seq[string]) =
  self.keycardServiceV2.asyncStoreMetadata(name, paths)

proc asyncImportLocalBackupFile*(self: Controller, filePath: string) =
  self.generalService.asyncImportLocalBackupFile(filePath)

proc startKeycardDetection*(self: Controller) =
  self.keycardServiceV2.startDetection()