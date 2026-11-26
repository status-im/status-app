import nimqml, json, strutils, chronicles


import ../settings/service as settings_service
import ../accounts/service as accounts_service

import ../../../app/core/eventemitter
import ../../../app/core/tasks/[qt, threadpool]

import ../../../backend/privacy as status_privacy

import ../../common/utils as common_utils
import ../../common/keychain_credential as keychain_credential
import ../../../app/global/global_singleton
import ./operation_result

include ./async_tasks

logScope:
  topics = "privacy-service"

# Signals which may be emitted by this service:
const SIGNAL_PASSWORD_CHANGED* = "passwordChanged"
const SIGNAL_PROFILE_PASSWORD_SET* = "profilePasswordSet"

type
  OperationSuccessArgs* = ref object of Args
    success*: bool
    errorMsg*: string

QtObject:
  type Service* = ref object of QObject
    events: EventEmitter
    settingsService: settings_service.Service
    accountsService: accounts_service.Service
    threadpool: threadpool.ThreadPool

  proc delete*(self: Service)
  proc newService*(events: EventEmitter, threadpool: threadpool.ThreadPool,
    settingsService: settings_service.Service,
    accountsService: accounts_service.Service): Service =
    new(result, delete)
    result.QObject.setup
    result.events = events
    result.threadpool = threadpool
    result.settingsService = settingsService
    result.accountsService = accountsService

  proc init*(self: Service) =
    discard

  proc onChangeDatabasePasswordResponse(self: Service, responseStr: string) {.slot.} =
    let res = operationResult(responseStr)
    if not res.success:
      error "error: ", procName="changePassword", errDesription = res.errorMsg
    self.events.emit(SIGNAL_PASSWORD_CHANGED, OperationSuccessArgs(success: res.success, errorMsg: res.errorMsg))

  proc onSetProfilePasswordResponse(self: Service, responseStr: string) {.slot.} =
    let res = operationResult(responseStr)
    if res.success:
      self.accountsService.clearLoggedInAccountZeroOnboarded()
      singletonInstance.userProfile.setZeroOnboarded(false)
    else:
      error "error: ", procName="setProfilePassword", errDesription = res.errorMsg
    self.events.emit(SIGNAL_PROFILE_PASSWORD_SET, OperationSuccessArgs(success: res.success, errorMsg: res.errorMsg))

  # Sets the first password of a zero-onboarded profile
  proc setProfilePassword*(self: Service, newPassword: string) =
    let arg = SetZeroOnboardedProfilePasswordTaskArg(
      tptr: setZeroOnboardedProfilePasswordTask,
      vptr: cast[uint](self.vptr),
      slot: "onSetProfilePasswordResponse",
      keyUid: self.accountsService.getLoggedInAccount().keyUid,
      newPassword: common_utils.hashPassword(newPassword)
    )
    self.threadpool.start(arg)

  proc changePassword*(self: Service, password: string, newPassword: string, rekey: bool = false) =
    try:
      let loggedInAccount = self.accountsService.getLoggedInAccount()
      let arg = ChangeDatabasePasswordTaskArg(
        tptr: changeDatabasePasswordTask,
        vptr: cast[uint](self.vptr),
        slot: "onChangeDatabasePasswordResponse",
        accountId: loggedInAccount.keyUid,
        currentPassword: common_utils.hashPassword(password),
        newPassword: common_utils.hashPassword(newPassword),
        rekey: rekey
      )
      self.threadpool.start(arg)

    except Exception as e:
      error "error: ", procName="changePassword", errName = e.name, errDesription = e.msg

  proc isProfileMigratedToDEKEncryption*(self: Service): bool =
    try:
      let loggedInAccount = self.accountsService.getLoggedInAccount()
      let response = status_privacy.getProfileEncryptionInfo(loggedInAccount.keyUid)
      return response.result{"migrated"}.getBool(false)
    except Exception as e:
      error "error: ", procName="isProfileMigratedToDEKEncryption", errName = e.name, errDesription = e.msg
      return false

  proc getBiometricCredentialForStorage*(self: Service, keyUid: string, password: string): string =
    return keychain_credential.biometricCredentialForPasswordProfile(keyUid, password)

  proc getStayLoggedInCredentialForStorage*(self: Service, keyUid: string, password: string): string =
    ## For the silently readable "Stay logged in" store: tagged DEK or "" — this
    ## conversion structurally cannot return a password (unlike the biometric one).
    return keychain_credential.dekCredentialForPasswordProfile(keyUid, password)

  proc isMnemonicBackedUp*(self: Service): bool =
    return self.settingsService.getMnemonic().len == 0

  proc getMnemonic*(self: Service): string =
    return self.settingsService.getMnemonic()

  proc removeMnemonic*(self: Service) =
    var data = OperationSuccessArgs(success: true)
    if(not self.settingsService.saveMnemonic("")):
      data.success = false
      error "error: ", procName="removeMnemonic", errDesription = "an error occurred removing mnemonic"

  proc mnemonicWasShown*(self: Service) =
    self.settingsService.mnemonicWasShown()

  proc delete*(self: Service) =
    self.QObject.delete

