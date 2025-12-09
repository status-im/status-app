import nimqml, chronicles, json, strutils, sequtils
import chronicles

import io_interface, states
import view, controller

import app/global/global_singleton
import app/core/eventemitter
import app_service/common/utils
import app_service/service/general/service as general_service
import app_service/service/accounts/service as accounts_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/devices/service as devices_service
import app_service/service/keycardV2/service as keycard_serviceV2
from app_service/service/settings/dto/settings import SettingsDto
from app_service/service/accounts/dto/accounts import AccountDto
from app_service/service/keycardV2/dto import KeycardEventDto, KeycardExportedKeysDto, KeycardState
import app/modules/onboarding/post_onboarding/[keycard_replacement_task, keycard_convert_account, save_biometrics_task, local_backup_task]

import models/login_account_item as login_acc_item

export io_interface, states

logScope:
  topics = "onboarding-module"

type
  Module*[T: io_interface.DelegateInterface] = ref object of io_interface.AccessInterface
    delegate: T
    view: View
    viewVariant: QVariant
    controller: Controller
    localPairingStatus: LocalPairingStatus
    loginFlow: LoginMethod
    onboardingFlow: OnboardingFlow
    exportedKeys: KeycardExportedKeysDto
    postOnboardingTasks: seq[PostOnboardingTask]
    postLoginTasks: seq[PostOnboardingTask]
    accountsService: accounts_service.Service
    generalService: general_service.Service

proc newModule*[T](
    delegate: T,
    events: EventEmitter,
    generalService: general_service.Service,
    accountsService: accounts_service.Service,
    walletAccountService: wallet_account_service.Service,
    devicesService: devices_service.Service,
    keycardServiceV2: keycard_serviceV2.Service,
  ): Module[T] =
  result = Module[T]()
  result.delegate = delegate
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.onboardingFlow = OnboardingFlow.Unknown
  result.loginFlow = LoginMethod.Unknown
  result.postOnboardingTasks = newSeq[PostOnboardingTask]()
  result.postLoginTasks = newSeq[PostOnboardingTask]()
  result.accountsService = accountsService
  result.generalService = generalService
  result.controller = controller.newController(
    result,
    events,
    generalService,
    accountsService,
    walletAccountService,
    devicesService,
    keycardServiceV2,
  )

{.push warning[Deprecated]: off.}

method delete*[T](self: Module[T]) =
  self.view.delete
  self.viewVariant.delete
  self.controller.delete

method onAppLoaded*[T](self: Module[T], keyUid: string) =
  # Doesn't do anything since we wait for the Main section to be loaded
  discard

method onMainLoaded*[T](self: Module[T]) =
  self.view.appLoaded()
  singletonInstance.engine.setRootContextProperty("onboardingModule", newQVariant())
  self.view.delete
  self.view = nil
  self.viewVariant.delete
  self.viewVariant = nil
  self.controller.delete
  self.controller = nil

method load*[T](self: Module[T]) =
  singletonInstance.engine.setRootContextProperty("onboardingModule", self.viewVariant)
  self.controller.init()

  let openedAccounts = self.controller.getOpenedAccounts()
  if openedAccounts.len > 0:
    var items: seq[login_acc_item.Item]
    for i in 0..<openedAccounts.len:
      let acc = openedAccounts[i]
      items.add(login_acc_item.initItem(
        order = i,
        acc.name,
        icon = "",
        acc.images.thumbnail,
        acc.images.large,
        acc.keyUid,
        acc.colorId,
        acc.keycardPairing
      ))

    self.view.setLoginAccountsModelItems(items)

  self.delegate.onboardingDidLoad()

method initialize*[T](self: Module[T], pin: string) =
  self.view.setPinSettingState(ProgressState.InProgress)
  self.controller.initialize(pin)

method authorize*[T](self: Module[T], pin: string) =
  self.view.setAuthorizationState(AuthorizationState.InProgress)
  self.controller.authorize(pin)

method getPasswordStrengthScore*[T](self: Module[T], password, userName: string): int =
  self.controller.getPasswordStrengthScore(password, userName)

method validMnemonic*[T](self: Module[T], mnemonic: string): bool =
  self.controller.validMnemonic(mnemonic)

method isMnemonicDuplicate*[T](self: Module[T], mnemonic: string): bool =
  self.controller.isMnemonicDuplicate(mnemonic)

method generateMnemonic*[T](self: Module[T]): string =
  return self.controller.generateMnemonic(SupportedMnemonicLength12)

method validateLocalPairingConnectionString*[T](self: Module[T], connectionString: string): bool =
  self.controller.validateLocalPairingConnectionString(connectionString)

method inputConnectionStringForBootstrapping*[T](self: Module[T], connectionString: string) =
  self.controller.inputConnectionStringForBootstrapping(connectionString)

method loadMnemonic*[T](self: Module[T], mnemonic: string) =
  self.view.setAddKeyPairState(ProgressState.InProgress)
  self.controller.loadMnemonic(mnemonic)

method finishOnboardingFlow*[T](self: Module[T], flowInt: int, dataJson: string): string =
  self.postOnboardingTasks = newSeq[PostOnboardingTask]()
  self.postLoginTasks = newSeq[PostOnboardingTask]()

  try:
    self.onboardingFlow = OnboardingFlow(flowInt)

    let data = parseJson(dataJson)
    let password = data["password"].str
    let mnemonic = data["seedphrase"].str
    let pin = data["keycardPin"].str
    let keyUid = data["keyUid"].str
    let keycardInfo = self.view.getKeycardEvent().keycardInfo
    let saveBiometrics = data["enableBiometrics"].getBool
    let backupImportFileUrl = data["backupImportFileUrl"].getStr
    let thirdpartyServicesEnabled = data["thirdpartyServicesEnabled"].getBool

    var err = ""

    case self.onboardingFlow:
      # CREATE PROFILE FLOWS
      of OnboardingFlow.CreateProfileWithPassword:
        err = self.controller.createAccountAndLogin(password, thirdpartyServicesEnabled)
      of OnboardingFlow.CreateProfileWithSeedphrase:
        err = self.controller.restoreAccountAndLogin(
          password,
          mnemonic,
          keycardInstanceUID = "",
          thirdpartyServicesEnabled,
        )
      of OnboardingFlow.CreateProfileWithKeycardNewSeedphrase:
        # New user with a seedphrase we showed them
        err = self.controller.restoreAccountAndLogin(
          password = "", # For keycard it will be substituted with `encryption.publicKey` in status-go
          mnemonic,
          keycardInstanceUID = keycardInfo.instanceUID,
          thirdpartyServicesEnabled,
        )
      of OnboardingFlow.CreateProfileWithKeycardExistingSeedphrase:
        # New user who entered their own seed phrase
        err = self.controller.restoreAccountAndLogin(
          password = "", # For keycard it will be substituted with `encryption.publicKey` in status-go
          mnemonic,
          keycardInstanceUID = keycardInfo.instanceUID,
          thirdpartyServicesEnabled,
        )

      # LOGIN FLOWS
      of OnboardingFlow.LoginWithSeedphrase:
        err = self.controller.restoreAccountAndLogin(
          password,
          mnemonic,
          keycardInstanceUID = "",
          thirdpartyServicesEnabled,
        )
      of OnboardingFlow.LoginWithSyncing:
        # The pairing was already done directly through inputConnectionStringForBootstrapping, we can login
        self.controller.loginLocalPairingAccount(
          self.localPairingStatus.account,
          self.localPairingStatus.password,
          self.localPairingStatus.chatKey,
        )
      of OnboardingFlow.LoginWithKeycard:
        err = self.controller.restoreKeycardAccountAndLogin(
          keycardInfo.keyUID,
          keycardInfo.instanceUID,
          self.exportedKeys,
          thirdpartyServicesEnabled,
        )
      of OnboardingFlow.LoginWithLostKeycardSeedphrase:
        # 1. Schedule `convertToRegularAccount` for post-onboarding
        self.postLoginTasks.add(newKeycardConvertAccountTask(
          keyUid,
          mnemonic,
          password,
        ))
        # 2. Set InProgress state
        self.view.setConvertKeycardAccountState(ProgressState.InProgress)
        # 3. Call LoginAccount with `mnemonic` set
        self.loginRequested(
          keyUid = keyUid,
          LoginMethod.Mnemonic.int,
          $ %*{ "mnemonic": mnemonic },
        )
      of OnboardingFlow.LoginWithRestoredKeycard:
        self.postOnboardingTasks.add(newKeycardReplacementTask(
          keycardInfo.keyUID,
          keycardInfo.instanceUID,
        ))
        self.loginRequested(
          keycardInfo.keyUID,
          LoginMethod.Keycard.int,
          $ %*{ "pin": pin },
        )
      else:
        raise newException(ValueError, "Unknown onboarding flow: " & $self.onboardingFlow)

    # SaveBiometrics task should be scheduled after any other tasks
    if saveBiometrics:
      let credential = if pin.len > 0: pin else: password
      self.postLoginTasks.add(newSaveBiometricsTask(credential))
    if backupImportFileUrl != "":
      self.postLoginTasks.add(newLocalBackupTask(backupImportFileUrl))

    return err
  except Exception as e:
    error "Error finishing Onboarding Flow", msg = e.msg
    return e.msg

method loginRequested*[T](self: Module[T], keyUid: string, loginFlow: int, dataJson: string) =
  try:
    self.loginFlow = LoginMethod(loginFlow)

    let data = parseJson(dataJson)
    let account = self.controller.getAccountByKeyUid(keyUid)

    case self.loginFlow:
      of LoginMethod.Password:
        self.controller.login(account, data["password"].str)
      of LoginMethod.Keycard:
        self.authorize(data["pin"].str)
        # We will continue the flow when the card is authorized in onKeycardStateUpdated
      of LoginMethod.Mnemonic:
        self.controller.login(account, password = "", mnemonic = data["mnemonic"].str)
      else:
        raise newException(ValueError, "Unknown login flow: " & $self.loginFlow)

  except Exception as e:
    error "Error finishing Login Flow", msg = e.msg
    self.view.accountLoginError(e.msg, wrongPassword = false)

proc syncAppAndKeycardState[T](self: Module[T]) =
  let kcEvent = self.view.getKeycardEvent()
  if kcEvent.keycardInfo.keyUID == "":
    return
  let keypair = self.controller.getKeypairByKeyUidFromDb(kcEvent.keycardInfo.keyUID)
  if keypair.isNil:
    return
  var
    pathsToStore: seq[string]
    addressesToStore: seq[string]
  for acc in keypair.accounts:
    if acc.isChat:
      continue
    if utils.isPathOutOfTheDefaultStatusDerivationTree(acc.path):
      return
    pathsToStore.add(acc.path)
    addressesToStore.add(acc.address)
  var kcName = kcEvent.metadata.name
  if kcName.len == 0:
    kcName = singletonInstance.userProfile.getName()
  if kcName.len == 0:
    kcName = "Status Keycard"
  self.controller.storeMetadata(kcName, pathsToStore)

  var kcDto = KeycardDto(keycardUid: kcEvent.keycardInfo.instanceUID,
    keycardName: kcName,
    keycardLocked: false,
    accountsAddresses: addressesToStore,
    keyUid: kcEvent.keycardInfo.keyUID)
  self.controller.addKeycardOrAccounts(kcDto, password = "")

proc finishAppLoading2[T](self: Module[T]) =

  let isOnboarding = self.loginFlow == LoginMethod.Unknown
  let eventType = if isOnboarding: "onboarding-completed" else: "user-logged-in"
  let flowType = if isOnboarding: repr(self.onboardingFlow) else : repr(self.loginFlow)
  singletonInstance.globalEvents.addCentralizedMetricIfEnabled(eventType, $(%*{"flowType": flowType}))

  self.syncAppAndKeycardState()

  self.controller.stopKeycardService()

  self.delegate.finishAppLoading()
  self.delegate.appReady()

method onAccountLoginError*[T](self: Module[T], error: string) =
  # SQLITE_NOTADB: "file is not a database"
  var wrongPassword = false
  if error.contains("file is not a database"):
    wrongPassword = true
  warn "failed to login", wrongPassword, error
  self.view.accountLoginError(error, wrongPassword)

method onNodeLogin*[T](self: Module[T], err: string, account: AccountDto, settings: SettingsDto) =
  if err.len != 0:
    self.onAccountLoginError(err)
    return

  self.controller.setLoggedInAccount(account)

  let err2 = self.delegate.userLoggedIn()
  if err2.len != 0:
    error "error from userLoggedIn", err2
    self.onAccountLoginError(err2)
    return

  if self.localPairingStatus != nil and self.localPairingStatus.installation != nil and
      self.localPairingStatus.installation.id != "" and self.localPairingStatus.state == LocalPairingState.Error:
    # We tried to login by pairing, so finalize the process
    self.controller.finishPairingThroughSeedPhraseProcess(self.localPairingStatus.installation.id)

  # Run any available post-login tasks
  self.runPostLoginTasks()

  # When converting account to regular, we should not finishAppLoading.
  # The task will convert the account, re-encrypt the database with new password and
  # eventually logout. The user will need to login with a new password.
  for i in 0..<self.postLoginTasks.len:
    let task = self.postLoginTasks[i]
    if task.kind == kConvertKeycardAccountToRegular:
      return

  self.finishAppLoading2()

method onLocalPairingStatusUpdate*[T](self: Module[T], status: LocalPairingStatus) =
  self.localPairingStatus = status
  self.view.setSyncState(status.state)

method onKeycardStateUpdated*[T](self: Module[T], keycardEvent: KeycardEventDto) =
  self.view.setKeycardEvent(keycardEvent)

  if keycardEvent.state == KeycardState.Authorized and self.loginFlow == LoginMethod.Keycard:
    # After authorizing, we export the keys
    self.controller.exportLoginKeysFromKeycard()
    # We will login once we have the keys in onKeycardExportLoginKeysSuccess

  if keycardEvent.state == KeycardState.NotEmpty and self.view.getPinSettingState() == ProgressState.InProgress.int:
    # We just finished setting the pin
    self.view.setPinSettingState(ProgressState.Success)

  if keycardEvent.state == KeycardState.Authorized and self.view.getAuthorizationState() == AuthorizationState.InProgress.int:
    # We just finished authorizing
    self.view.setAuthorizationState(AuthorizationState.Authorized)

method onKeycardSetPinFailure*[T](self: Module[T], error: string) =
  self.view.setPinSettingState(ProgressState.Failed)

method onKeycardAuthorizeFinished*[T](self: Module[T], error: string, authorized: bool) =
  if error != "":
    self.view.setAuthorizationState(AuthorizationState.Error)
  elif not authorized:
    self.view.setAuthorizationState(AuthorizationState.WrongPIN)
  else:
    self.view.setAuthorizationState(AuthorizationState.Authorized)
    return

  if self.loginFlow == LoginMethod.Keycard:
    # We were trying to login and the authorization failed
    self.view.accountLoginError(error, not authorized)

method onKeycardLoadMnemonicFailure*[T](self: Module[T], error: string) =
  self.view.setAddKeyPairState(ProgressState.Failed)

method onKeycardLoadMnemonicSuccess*[T](self: Module[T], keyUID: string) =
  self.view.setAddKeyPairState(ProgressState.Success)

method onKeycardExportRestoreKeysFailure*[T](self: Module[T], error: string) =
  self.view.setRestoreKeysExportState(ProgressState.Failed)

method onKeycardExportRestoreKeysSuccess*[T](self: Module[T], exportedKeys: KeycardExportedKeysDto) =
  self.exportedKeys = exportedKeys
  self.view.setRestoreKeysExportState(ProgressState.Success)

method onKeycardExportLoginKeysFailure*[T](self: Module[T], error: string) =
  self.view.accountLoginError(error, wrongPassword = false)

method onKeycardExportLoginKeysSuccess*[T](self: Module[T], exportedKeys: KeycardExportedKeysDto) =
  let keycardInfo = self.view.getKeycardEvent().keycardInfo
  # We got the keys, now we can login. If everything goes well, we will finish the app loading
  let accountDto = self.controller.getAccountByKeyUid(keycardInfo.keyUID)
  self.controller.login(
    accountDto,
    password = "",
    keycard = true,
    publicEncryptionKey = exportedKeys.encryptionKey.publicKey,
    privateWhisperKey = exportedKeys.whisperKey.privateKey,
  )

method onKeycardAccountConverted*[T](self: Module[T], success: bool) =
  let state = if success: ProgressState.Success else: ProgressState.Failed
  self.view.setConvertKeycardAccountState(state)
  self.generalService.logout()

method exportRecoverKeys*[T](self: Module[T]) =
  self.view.setRestoreKeysExportState(ProgressState.InProgress)
  self.controller.exportRecoverKeysFromKeycard()

method startKeycardFactoryReset*[T](self: Module[T]) =
  self.controller.startKeycardFactoryReset()

method getPostOnboardingTasks*[T](self: Module[T]): seq[PostOnboardingTask] =
  return self.postOnboardingTasks

method requestSaveBiometrics*[T](self: Module[T], account: string, credential: string) =
  self.view.saveBiometricsRequested(account, credential)

method requestLocalBackup*[T](self: Module[T], backupImportFileUrl: string) =
  self.controller.asyncImportLocalBackupFile(backupImportFileUrl)

method requestDeleteBiometrics*[T](self: Module[T], account: string) =
  self.view.deleteBiometricsRequested(account)

method startKeycardDetection*[T](self: Module[T]) =
  self.controller.startKeycardDetection()

proc runPostLoginTasks*[T](self: Module[T]) =
  let tasks = self.postLoginTasks
  for task in tasks:
    case task.kind:
    of kConvertKeycardAccountToRegular:
      KeycardConvertAccountTask(task).run(self.accountsService, self)
    of kPostOnboardingTaskSaveBiometrics:
      SaveBiometricsTask(task).run(self.accountsService, self)
    of kPostOnboardingTaskLocalBackup:
      LocalBackupTask(task).run(self)
    else:
      error "unknown post login task"

{.pop.}
