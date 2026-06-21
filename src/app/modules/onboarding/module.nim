import nimqml, chronicles, json, strutils, sequtils

import io_interface, states
import view, controller
import app/modules/shared_modules/keycard_management/module as keycard_management_module

import app/global/feature_flags
import app/global/global_singleton
import app/core/eventemitter
import app_service/common/account_constants
import app_service/service/general/service as general_service
import app_service/service/accounts/service as accounts_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/devices/service as devices_service
import app_service/service/keycardV2/service as keycard_serviceV2
from app_service/service/settings/dto/settings import SettingsDto
from app_service/service/accounts/dto/accounts import AccountDto
from app_service/service/keycardV2/dto import KeycardEventDto, KeycardExportedKeysDto, KeycardState, toKeycardExportedKeysDto
import app/modules/onboarding/post_onboarding/[keycard_replacement_task, keycard_convert_account, save_biometrics_task, local_backup_task]

import models/login_account_item as login_acc_item

export io_interface, states

logScope:
  topics = "onboarding-module"

const IS_MOBILE = defined(ios) or defined(android)

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
    resumeLogin: bool
    tmpKeyUid: string # TODO: remove this, once we switch fully to new keycard approach
    keycardModule: keycard_management_module.Module[Module[T]]
    events: EventEmitter
    keycardServiceV2: keycard_serviceV2.Service

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
  result.events = events
  result.keycardServiceV2 = keycardServiceV2
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

# Forward declarations (needed because some methods call procs defined later).
proc finishAppLoading2*[T](self: Module[T])

method prepareKeycardModule*[T](self: Module[T]) =
  if not self.keycardModule.isNil:
    return
  self.keycardModule = keycard_management_module.newModule[Module[T]](self, self.events, self.keycardServiceV2,
    self.accountsService, walletAccountService = nil, privacyService = nil)
  self.view.setKeycardModule(self.keycardModule.getModuleAsVariant())

method destroyKeycardModule*[T](self: Module[T]) =
  if self.keycardModule.isNil:
    return
  self.keycardModule.delete
  self.keycardModule = nil
  self.view.setKeycardModule(newQVariant())

method delete*[T](self: Module[T]) =
  if not self.keycardModule.isNil:
    self.keycardModule.delete
    self.keycardModule = nil
  self.view.delete
  self.viewVariant.delete
  self.controller.delete

method onAppLoaded*[T](self: Module[T], keyUid: string) =
  # Doesn't do anything since we wait for the Main section to be loaded
  discard

method onMainLoaded*[T](self: Module[T]) =
  if self.view.isNil:
    return

  self.view.appLoaded()

method cleanupAfterMainTransition*[T](self: Module[T]) =
  if self.view.isNil:
    return

  singletonInstance.engine.setRootContextProperty("onboardingModule", newQVariant())
  if not self.keycardModule.isNil:
    self.keycardModule.delete
    self.keycardModule = nil
  self.view.delete
  self.view = nil
  self.viewVariant.delete
  self.viewVariant = nil
  self.controller.delete
  self.controller = nil

method onMainFailedToLoad*[T](self: Module[T]) =
  self.view.accountLoginError("Failed to load main module, please restart the app and try again.", wrongPassword = false)

method load*[T](self: Module[T]) =
  singletonInstance.engine.setRootContextProperty("onboardingModule", self.viewVariant)
  self.controller.init()

  let loggedInAccount = self.accountsService.fetchLoggedInAccount()
  self.resumeLogin = loggedInAccount.isValid()
  if self.resumeLogin:
    self.controller.setLoggedInAccount(loggedInAccount)
    self.finishAppLoading2()
    return

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

method loginKeycard*[T](self: Module[T], keyUid: string, pin: string) =
  self.controller.loginKeycard(keyUid, pin)

method getPasswordStrengthScore*[T](self: Module[T], password, userName: string): int =
  self.controller.getPasswordStrengthScore(password, userName)

method validMnemonic*[T](self: Module[T], mnemonic: string): bool =
  self.controller.validMnemonic(mnemonic)

method isMnemonicDuplicate*[T](self: Module[T], mnemonic: string): bool =
  self.controller.isMnemonicDuplicate(mnemonic)

method validateLocalPairingConnectionString*[T](self: Module[T], connectionString: string): bool =
  self.controller.validateLocalPairingConnectionString(connectionString)

method inputConnectionStringForBootstrapping*[T](self: Module[T], connectionString: string) =
  self.controller.inputConnectionStringForBootstrapping(connectionString)

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
        discard # not in use anymore
      of OnboardingFlow.CreateProfileWithKeycardExistingSeedphrase:
        discard # not in use anymore

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
        discard # not in use anymore
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
        discard # not in use anymore

      # #########################################################
      # New Onboarding Keycard flows
      # #########################################################
      of OnboardingFlow.OnboardingLoginWithKeycard:
        let payload = data{"keycardPayload"}
        if payload.isNil or payload.kind != JObject:
          raise newException(ValueError, "OnboardingLoginWithKeycard: missing keycardPayload")
        let payloadKeyUid = payload{"keyUid"}.getStr
        let payloadKeycardUid = payload{"keycardUid"}.getStr
        let exportedKeys = toKeycardExportedKeysDto(payload{"exportedKeys"})
        self.tmpKeyUid = payloadKeyUid
        err = self.controller.restoreKeycardAccountAndLogin(
          payloadKeyUid,
          payloadKeycardUid,
          exportedKeys,
          thirdpartyServicesEnabled,
        )
      of OnboardingFlow.OnboardingImportNewKeyPair, OnboardingFlow.OnboardingImportSeedPhrase:
        let selectedProfileKeyUid = data{"selectedProfileKeyUid"}.getStr
        let payload = data{"keycardPayload"}
        if payload.isNil or payload.kind != JObject:
          raise newException(ValueError, "Onboarding import flow: missing keycardPayload")
        let payloadSeedPhrase = payload{"seedPhrase"}.getStr
        let payloadKeyUid = payload{"keyUid"}.getStr
        let payloadKeycardUid = payload{"keycardUid"}.getStr
        self.tmpKeyUid = payloadKeyUid
        if selectedProfileKeyUid.len > 0 and selectedProfileKeyUid == payloadKeyUid:
          # Importing a new key pair for an existing profile
          let derivations = self.controller.createAccountFromMnemonic(payloadSeedPhrase, @[PATH_ENCRYPTION, PATH_WHISPER])
          if derivations.derivedAccounts.encryption.publicKey.len == 0 or derivations.derivedAccounts.whisper.privateKey.len == 0:
            err = "failed to derive encryption public key or whisper private key from seed phrase"
          else:
            let accountDto = self.controller.getAccountByKeyUid(self.tmpKeyUid)
            self.controller.login(
              accountDto,
              password = "",
              keycard = true,
              publicEncryptionKey = derivations.derivedAccounts.encryption.publicKey,
              privateWhisperKey = derivations.derivedAccounts.whisper.privateKey,
            )
        else:
          err = self.controller.restoreAccountAndLogin(
            password = "",
            mnemonic = payloadSeedPhrase,
            keycardInstanceUID = payloadKeycardUid,
            thirdpartyServicesEnabled,
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
    self.tmpKeyUid = keyUid
    self.loginFlow = LoginMethod(loginFlow)

    let data = parseJson(dataJson)
    let account = self.controller.getAccountByKeyUid(keyUid)

    case self.loginFlow:
      of LoginMethod.Password:
        self.controller.login(account, data["password"].str)
      of LoginMethod.Keycard:
        self.loginKeycard(keyUid, data["pin"].str)
      of LoginMethod.Mnemonic:
        self.controller.login(account, password = "", mnemonic = data["mnemonic"].str)
      else:
        raise newException(ValueError, "Unknown login flow: " & $self.loginFlow)

  except Exception as e:
    error "Error finishing Login Flow", msg = e.msg
    self.view.accountLoginError(e.msg, wrongPassword = false)

proc finishAppLoading2[T](self: Module[T]) =
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
  discard self.delegate.userLoggedIn()

method onMessengerStarted*[T](self: Module[T], err: string) =
  if err.len != 0:
    error "error starting messenger", err
    self.onAccountLoginError(err)
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

method onKeycardExportLoginKeysFailure*[T](self: Module[T], error: string) =
  self.view.accountLoginError(error, wrongPassword = true)

method onKeycardExportLoginKeysSuccess*[T](self: Module[T], exportedKeys: KeycardExportedKeysDto) =
  if self.loginFlow != LoginMethod.Keycard:
    info "login flow is not keycard, skipping further processing", loginFlow = $self.loginFlow
    return
  let accountDto = self.controller.getAccountByKeyUid(self.tmpKeyUid)
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

method getPostOnboardingTasks*[T](self: Module[T]): seq[PostOnboardingTask] =
  return self.postOnboardingTasks

method requestSaveBiometrics*[T](self: Module[T], account: string, credential: string) =
  self.view.saveBiometricsRequested(account, credential)

method requestLocalBackup*[T](self: Module[T], backupImportFileUrl: string) =
  self.controller.asyncImportLocalBackupFile(backupImportFileUrl)

method requestDeleteBiometrics*[T](self: Module[T], account: string) =
  self.view.deleteBiometricsRequested(account)

method requestDeleteMultiaccount*[T](self: Module[T], keyUid: string): string =
  let err = self.controller.deleteMultiaccount(keyUid)
  if err.len > 0:
    return err

  self.view.removeLoginAccountItem(keyUid)
  return ""

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
