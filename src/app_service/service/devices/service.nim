import nimqml, json, sequtils, system, chronicles, uuids, strutils

import std/os

import ./dto/installation as Installation_dto
import ./dto/local_pairing_event
import ./dto/local_pairing_status

import app_service/service/settings/service as settings_service
import app_service/service/accounts/service as accounts_service
import app_service/service/wallet_account/service as wallet_account_service
import ../../common/activity_center

import app/global/global_singleton
import app/core/[main]
import app/core/signals/types
import app/core/eventemitter
import app/core/tasks/[qt, threadpool]
when defined(android):
  import app/android/safutils
import backend/installations as status_installations
import app_service/common/utils as utils
import constants as main_constants

import status_go

export Installation_dto
export local_pairing_event
export local_pairing_status

include async_tasks

logScope:
  topics = "devices-service"

type
  UpdateInstallationArgs* = ref object of Args
    installation*: InstallationDto

type
  UpdateInstallationNameArgs* = ref object of Args
    installationId*: string
    name*: string

type
  DevicesArg* = ref object of Args
    devices*: seq[InstallationDto]

type
  BackupCompletedArg* = ref object of Args
    error*: string

# Signals which may be emitted by this service:
const SIGNAL_UPDATE_DEVICE* = "updateDevice"
const SIGNAL_DEVICES_LOADED* = "devicesLoaded"
const SIGNAL_ERROR_LOADING_DEVICES* = "devicesErrorLoading"
const SIGNAL_LOCAL_PAIRING_STATUS_UPDATE* = "localPairingStatusUpdate"
const SIGNAL_INSTALLATION_NAME_UPDATED* = "installationNameUpdated"
const SIGNAL_PAIRING_FALLBACK_COMPLETED* = "pairingFallbackCompleted"
const SIGNAL_BACKUP_COMPLETED* = "backupCompleted"

QtObject:
  type Service* = ref object of QObject
    events: EventEmitter
    threadpool: ThreadPool
    settingsService: settings_service.Service
    accountsService: accounts_service.Service
    walletAccountService: wallet_account_service.Service
    localPairingStatus: LocalPairingStatus

  proc delete*(self: Service)
  proc newService*(events: EventEmitter,
    threadpool: ThreadPool,
    settingsService: settings_service.Service,
    accountsService: accounts_service.Service,
    walletAccountService: wallet_account_service.Service): Service =
      new(result, delete)
      result.QObject.setup
      result.events = events
      result.threadpool = threadpool
      result.settingsService = settingsService
      result.accountsService = accountsService
      result.walletAccountService = walletAccountService

  proc updateLocalPairingStatus(self: Service, data: LocalPairingEventArgs) =
    self.localPairingStatus.update(data)
    self.events.emit(SIGNAL_LOCAL_PAIRING_STATUS_UPDATE, self.localPairingStatus)

  proc doConnect(self: Service) =
    self.events.on(SignalType.Message.event) do(e:Args):
      let receivedData = MessageSignal(e)
      for dto in receivedData.installations:
        let data = UpdateInstallationArgs(
          installation: dto)
        self.events.emit(SIGNAL_UPDATE_DEVICE, data)

    self.events.on(SignalType.LocalPairing.event) do(e:Args):
      let signalData = LocalPairingSignal(e)
      if self.localPairingStatus.pairingType == PairingType.AppSync:
        let data = LocalPairingEventArgs(
          eventType: signalData.eventType,
          action: signalData.action,
          accountData: signalData.accountData,
          installation: signalData.installation,
          error: signalData.error)
        self.updateLocalPairingStatus(data)
      elif self.localPairingStatus.pairingType == PairingType.KeypairSync:
        let data = LocalPairingEventArgs(
          eventType: signalData.eventType,
          action: signalData.action,
          error: signalData.error,
          transferredKeypairs: signalData.transferredKeypairs)
        self.updateLocalPairingStatus(data)

    # Android SAF: if user-selected backup path is a content:// tree URI, copy the produced
    # backup file from our default directory into that tree using SAF helper.
    when defined(android):
      self.events.on(SignalType.BackUpCompleted.event) do(e:Args):
        try:
          let receivedData = BackUpCompletedSignal(e)
          
          if receivedData.fileName.len == 0:
            raise newException(CatchableError, "no backup file name received")

          let backupPath = singletonInstance.localAccountSensitiveSettings.getLocalBackupChosenPath()

          if backupPath.len == 0 or not backupPath.startsWith("content://"):
            raise newException(CatchableError, "invalid backup path for SAF copy")

          # Take persistable permission for the selected tree URI
          safTakePersistablePermission(backupPath)

          let fileName = splitFile(receivedData.fileName).name & splitFile(receivedData.fileName).ext
          let destUri = safCopyFromPathToTree(receivedData.fileName, backupPath, "application/octet-stream", fileName)
          if destUri.len == 0:
            raise newException(CatchableError, "Failed to export backup into selected folder (SAF)")

          self.events.emit(SIGNAL_BACKUP_COMPLETED, BackupCompletedArg(error: ""))
        except Exception as e:
          error "error: ", procName="performLocalBackup/SAF", errName = e.name, errDesription = e.msg
          self.events.emit(SIGNAL_BACKUP_COMPLETED, BackupCompletedArg(error: e.msg))

  proc init*(self: Service) =
    self.doConnect()

  proc asyncLoadDevices*(self: Service) =
    let arg = AsyncLoadDevicesTaskArg(
      tptr: asyncLoadDevicesTask,
      vptr: cast[uint](self.vptr),
      slot: "asyncDevicesLoaded",
    )
    self.threadpool.start(arg)

  proc asyncDevicesLoaded*(self: Service, response: string) {.slot.} =
    try:
      let responseObj = response.parseJson
      if responseObj{"error"}.kind != JNull and responseObj{"error"}.getStr != "":
        raise newException(CatchableError, responseObj{"error"}.getStr)

      let installations = map(responseObj["response"].getElems(), proc(x: JsonNode): InstallationDto = x.toInstallationDto())
      self.events.emit(SIGNAL_DEVICES_LOADED, DevicesArg(devices: installations))
    except Exception as e:
      error "Erorr load devices async", msg = e.msg
      self.events.emit(SIGNAL_ERROR_LOADING_DEVICES, Args())

  proc getAllDevices*(self: Service): seq[InstallationDto] =
    try:
      let response = status_installations.getOurInstallations()
      return map(response.result.getElems(), proc(x: JsonNode): InstallationDto = x.toInstallationDto())
    except Exception as e:
      error "error: ", desription = e.msg

  proc setInstallationName*(self: Service, installationId: string, name: string) =
    # Once we get more info from `status-go` we may emit success/failed signal from here.
    try:
      let response = status_installations.setInstallationName(installationId, name)
      if response.error != nil:
        let e = Json.decode($response.error, RpcError)
        error "error: ", errorDescription = e.message
        return
      let data = UpdateInstallationNameArgs(installationId: installationId, name: name)
      self.events.emit(SIGNAL_INSTALLATION_NAME_UPDATED, data)
    except Exception as e:
      error "error: ", desription = e.msg

  proc syncAllDevices*(self: Service) =
    let preferredName = self.settingsService.getPreferredName()
    # Once we get more info from `status-go` we may emit success/failed signal from here.
    discard status_installations.syncDevices(preferredName, "")

  proc advertise*(self: Service) =
    # Once we get more info from `status-go` we may emit success/failed signal from here.
    discard status_installations.sendPairInstallation()


  #
  # Local Pairing
  #

  proc inputConnectionStringForBootstrappingFinished*(self: Service, responseJson: string) {.slot.} =
    try:
      var currentError = ""
      if self.localPairingStatus.state == LocalPairingState.Error:
        # The error was already returned by an event, keep it to reuse
        currentError = self.localPairingStatus.error

      let response = responseJson.parseJson

      if response["error"].kind != JNull:
        var errorDescription = response["error"].getStr
        if len(errorDescription) == 0:
          # Error is not a string
          error "non-string error during inputConnectionStringForBootstrappingFinished", error = response["error"]
          errorDescription = "error occurred"
        raise newException(CatchableError, errorDescription)

      var installation = InstallationDto()
      installation.id = response["installationId"].getStr # Set the installation with the ID (only info we have for now)
      let data = LocalPairingEventArgs(
        installation: installation, 
        eventType: EventCompletedAndNodeReady,
        action: ActionPairingInstallation,
        accountData: LocalPairingAccountData(),
        error: currentError,
      )
      self.updateLocalPairingStatus(data)

    except Exception as e:
      error "failed to start bootstrapping device", error = e.msg
      let data = LocalPairingEventArgs(
        eventType: EventConnectionError,
        action: ActionUnknown,
        accountData: LocalPairingAccountData(),
        error: e.msg,
      )
      self.updateLocalPairingStatus(data)

  proc validateConnectionString*(self: Service, connectionString: string): string =
    if connectionString.len == 0:
      result = "an empty connection string provided"
      error "error", msg=result
      return
    return status_go.validateConnectionString(connectionString)

  proc getConnectionStringForBootstrappingAnotherDevice*(self: Service, password: string, chatKey: string, messageSyncingEnabled: bool): string =
    let keyUid = singletonInstance.userProfile.getKeyUid()
    let keycardUser = singletonInstance.userProfile.getIsKeycardUser()
    var finalPassword = utils.hashPassword(password)
    if keycardUser:
      finalPassword = password
    let configJSON = %* {
      "senderConfig": %* {
        "keystorePath": joinPath(main_constants.ROOTKEYSTOREDIR, keyUid),
        "deviceType": hostOs,
        "keyUID": keyUid,
        "password": finalPassword,
        "chatKey": chatKey,
        "messageSyncingEnabled": messageSyncingEnabled
      },
      "serverConfig": %* {
        "timeout": 5 * 60 * 1000,
      }
    }
    self.localPairingStatus = newLocalPairingStatus(PairingType.AppSync, LocalPairingMode.Sender)
    return status_go.getConnectionStringForBootstrappingAnotherDevice($configJSON)

  proc inputConnectionStringForBootstrapping*(self: Service, connectionString: string) =

    let configJSON = %* {
      "receiverConfig": %* {
        "createAccount": %*accounts_service.defaultCreateAccountRequest(),
      },
      "clientConfig": %* {}
    }
    self.localPairingStatus = newLocalPairingStatus(PairingType.AppSync, LocalPairingMode.Receiver)
    let arg = AsyncInputConnectionStringArg(
      tptr: asyncInputConnectionStringTask,
      vptr: cast[uint](self.vptr),
      slot: "inputConnectionStringForBootstrappingFinished",
      connectionString: connectionString,
      configJSON: $configJSON
    )
    self.threadpool.start(arg)


  proc validateKeyUids*(self: Service, keyUids: seq[string], validateForExport: bool): tuple[finalKeyUids: seq[string], err: string] =
    if keyUids.len > 0:
      for keyUid in keyUids:
        let kp = self.walletAccountService.getKeypairByKeyUid(keyUid)
        if kp.isNil:
          result.err = "cannot resolve keypair for provided keyUid"
          return
        if kp.migratedToKeycard() or kp.keypairType == KeypairTypeProfile:
          result.err = "keypair is migrated to a keycard or refers to a profile keypair"
          return
        if validateForExport:
          if kp.getOperability() == AccountNonOperable:
            result.err = "cannot export non operable keypair"
            return
        elif kp.getOperability() != AccountNonOperable:
          result.err = "keypair is already fully or partially operable"
          return
        result.finalKeyUids.add(kp.keyUid)
    else:
      let keypairs = self.walletAccountService.getKeypairs()
      for kp in keypairs:
        if kp.migratedToKeycard() or
          kp.keypairType == KeypairTypeProfile or
          validateForExport and kp.getOperability() == AccountNonOperable or
          not validateForExport and kp.getOperability() != AccountNonOperable:
            continue
        result.finalKeyUids.add(kp.keyUid)

    if result.finalKeyUids.len == 0:
      result.err = "there is no valid keypair"

  ## Providing an empty array of keyUids means generating a connection string and transferring all non operable keypairs
  proc generateConnectionStringForExportingKeypairsKeystores*(self: Service, keyUids: seq[string], password: string): tuple[res: string, err: string] =
    if password.len == 0:
      result.err = "emtpy password provided"
      error "error", msg=result.err
      return
    let(finalKeyUids, err) = self.validateKeyUids(keyUids, validateForExport=true)
    if err.len > 0:
      result.err = err
      error "error", msg=err
      return

    let loggedInUserKeyUid = singletonInstance.userProfile.getKeyUid()
    let keycardUser = singletonInstance.userProfile.getIsKeycardUser()

    var finalPassword = utils.hashPassword(password)
    if keycardUser:
      finalPassword = password

    let configJSON = %* {
      "senderConfig": %* {
        "keystorePath": joinPath(main_constants.ROOTKEYSTOREDIR, loggedInUserKeyUid),
        "loggedInKeyUid": loggedInUserKeyUid,
        "password": finalPassword,
        "keypairsToExport": finalKeyUids,
      },
      "serverConfig": %* {
        "timeout": 5 * 60 * 1000,
      }
    }
    self.localPairingStatus = newLocalPairingStatus(PairingType.KeypairSync, LocalPairingMode.Sender)
    let response = status_go.getConnectionStringForExportingKeypairsKeystores($configJSON)
    try:
      let jsonObj = response.parseJson
      if jsonObj.hasKey("error"):
        return ("", jsonObj["error"].getStr)
    except Exception:
      return (response, "")

  proc inputConnectionStringForImportingKeystoreFinished*(self: Service, responseJson: string) {.slot.} =
    try:
      let jsonObj = responseJson.parseJson
      if jsonObj.hasKey("error") and jsonObj["error"].getStr.len == 0:
        info "keystore files successfully transferred"
        self.walletAccountService.updateKeypairOperabilityInLocalStoreAndNotify(self.localPairingStatus.transferredKeypairs)
        return
      let errorDescription = jsonObj["error"].getStr
      error "failed to start transferring keystore files", errorDescription
      self.events.emit(SIGNAL_IMPORTED_KEYPAIRS, KeypairsArgs(error: errorDescription))
    except Exception as e:
      error "unexpected error", msg=e.msg

  ## Providing an empty array of keyUids means expecting keystore files for all non operable keypairs to be received
  proc inputConnectionStringForImportingKeypairsKeystores*(self: Service, keyUids: seq[string], connectionString: string, password: string): string =
    if password.len == 0:
      result = "emtpy password provided"
      error "error", msg=result
      return
    let(finalKeyUids, err) = self.validateKeyUids(keyUids, validateForExport=false)
    if err.len > 0:
      result = err
      error "error", msg=result
      return

    let loggedInUserKeyUid = singletonInstance.userProfile.getKeyUid()
    let keycardUser = singletonInstance.userProfile.getIsKeycardUser()

    var finalPassword = utils.hashPassword(password)
    if keycardUser:
      finalPassword = password

    let configJSON = %* {
      "receiverConfig": %* {
        "keystorePath": main_constants.ROOTKEYSTOREDIR,
        "loggedInKeyUid": loggedInUserKeyUid,
        "password": finalPassword,
        "keypairsToImport": finalKeyUids,
      },
      "clientConfig": %* {}
    }
    self.localPairingStatus = newLocalPairingStatus(PairingType.KeypairSync, LocalPairingMode.Receiver)

    let arg = AsyncInputConnectionStringArg(
      tptr: asyncInputConnectionStringForImportingKeystoreTask,
      vptr: cast[uint](self.vptr),
      slot: "inputConnectionStringForImportingKeystoreFinished",
      connectionString: connectionString,
      configJSON: $configJSON
    )
    self.threadpool.start(arg)

  proc finishPairingThroughSeedPhraseProcess*(self: Service, installationId: string) =
    try:
      let response = status_installations.finishPairingThroughSeedPhraseProcess(installationId)
      if response.error != nil:
        let e = Json.decode($response.error, RpcError)
        raise newException(CatchableError, e.message)
    except Exception as e:
      error "error: ", desription = e.msg

  proc enableInstallationAndSync*(self: Service, installationId: string) =
    try:
      let response = status_installations.enableInstallationAndSync(installationId)
      if response.error != nil:
        let e = Json.decode($response.error, RpcError)
        raise newException(CatchableError, e.message)
      # Parse AC notif
      checkAndEmitACNotificationsFromResponse(self.events, response.result{"activityCenterNotifications"})
      self.events.emit(SIGNAL_PAIRING_FALLBACK_COMPLETED, Args())
    except Exception as e:
      error "error: ", desription = e.msg

  proc unpairDevice*(self: Service, installationId: string): string =
    try:
      let response = status_installations.unpairDevice(installationId)
      if response.error != nil:
        let e = Json.decode($response.error, RpcError)
        raise newException(CatchableError, e.message)
    except Exception as e:
      error "error in unpairDevice: ", desription = e.msg
      return e.msg

  proc pairDevice*(self: Service, installationId: string): string =
    try:
      let response = status_installations.pairDevice(installationId)
      if response.error != nil:
        let e = Json.decode($response.error, RpcError)
        raise newException(CatchableError, e.message)
    except Exception as e:
      error "error in pairDevice: ", desription = e.msg
      return e.msg

  proc performLocalBackup*(self: Service) =
    try:
      let response =  status_go.performLocalBackup()
      let rpcResponseObj = response.parseJson

      if rpcResponseObj.hasKey("error") and rpcResponseObj{"error"}.getStr != "":
        raise newException(CatchableError, rpcResponseObj{"error"}.getStr)

      when not defined(android):
        # On Android, the BackUpCompleted signal handler will do the emitting after SAF copy
        # All other platforms just emit here because the backup file is already in the desired location
        self.events.emit(SIGNAL_BACKUP_COMPLETED, BackupCompletedArg(error: ""))
    except Exception as e:
      error "error: ", procName="performLocalBackup", errName = e.name, errDesription = e.msg
      self.events.emit(SIGNAL_BACKUP_COMPLETED, BackupCompletedArg(error: e.msg))

  proc delete*(self: Service) =
    self.QObject.delete

