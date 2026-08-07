import nimqml, json, strutils, chronicles


import ../settings/service as settings_service
import ../accounts/service as accounts_service

import ../../../app/core/eventemitter
import ../../../app/core/tasks/[qt, threadpool]

import ../../../backend/privacy as status_privacy

import ../../common/utils as common_utils

include ./async_tasks

logScope:
  topics = "privacy-service"

# Signals which may be emitted by this service:
const SIGNAL_PASSWORD_CHANGED* = "passwordChanged"

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
    var data = OperationSuccessArgs(success: false, errorMsg: "")
    try:
      let response = responseStr.parseJson

      # nim runtime error
      let error = response["error"].getStr
      if error != "":
        data.errorMsg = error
        self.events.emit(SIGNAL_PASSWORD_CHANGED, data)
        return;

      let result = response["result"]

      if(result.contains("error")):
        let errMsg = result["error"].getStr
        if(errMsg.len == 0):
          data.success = true
        else:
          # backend runtime error
          data.errorMsg = errMsg
          error "error: ", procName="changePassword", errDesription = errMsg

    except Exception as e:
      error "error: ", procName="changePassword", errName = e.name, errDesription = e.msg
      data.errorMsg = e.msg

    self.events.emit(SIGNAL_PASSWORD_CHANGED, data)


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

