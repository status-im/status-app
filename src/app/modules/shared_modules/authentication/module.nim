import nimqml, chronicles

import io_interface
import view, controller
import app/core/eventemitter

import app/global/global_singleton
import app_service/common/account_constants
import app_service/service/accounts/service as accounts_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/keycardV2/service as keycard_serviceV2

export io_interface

logScope:
  topics = "authentication-module"

type
  Module*[T: io_interface.DelegateInterface] = ref object of io_interface.AccessInterface
    delegate: T
    view: View
    viewVariant: QVariant
    controller: Controller

proc newModule*[T](delegate: T,
  events: EventEmitter,
  accountsService: accounts_service.Service,
  walletAccountService: wallet_account_service.Service,
  keycardServiceV2: keycard_serviceV2.Service):
  Module[T] =
  result = Module[T]()
  result.delegate = delegate
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, events, accountsService, walletAccountService, keycardServiceV2)
  result.controller.init()

{.push warning[Deprecated]: off.}

method delete*[T](self: Module[T]) =
  self.view.delete
  self.viewVariant.delete
  self.controller.delete

method getModuleAsVariant*[T](self: Module[T]): QVariant =
  return self.viewVariant

method verifyPassword*[T](self: Module[T], password: string): bool =
  return self.controller.verifyPassword(password)

method isKeypairMigratedToKeycard*[T](self: Module[T], keyUid: string): bool =
  return self.controller.isKeypairMigratedToKeycard(keyUid)

method startKeycardAuthentication*[T](self: Module[T], keyUid: string, pin: string) =
  let
    targetKeyUid = if keyUid.len > 0: keyUid
                   else: singletonInstance.userProfile.getKeyUid()
    paths = @[account_constants.PATH_ENCRYPTION]
    exportPrivate = true
    exportMasterAddr = false
  self.controller.startKeycardAuthentication(targetKeyUid, paths, exportPrivate, exportMasterAddr, pin)

method stopKeycardAuthentication*[T](self: Module[T]) =
  self.controller.stopKeycardAuthentication()

method onKeycardStateUpdated*[T](self: Module[T], kcEvent: KeycardEventDto) =
  self.view.setKeycardState($kcEvent.stateString)
  self.view.setRemainingPinAttempts(kcEvent.keycardStatus.remainingAttemptsPIN)

method onKeycardExportPublicKeysFinished*[T](self: Module[T], exportedPublicKeys: KeycardExportedPublicKeysDto, error: string) =
  if error.len > 0:
    error "exporting public keys error", error=error
    self.view.keycardAuthError(error)
    return
  if exportedPublicKeys.keys.len != 1:
    error "exporting public keys error", error="expected 1 key, got " & $exportedPublicKeys.keys.len
    self.view.keycardAuthError(error)
    return
  let encryptionPublicKey = exportedPublicKeys.keys[0].publicKey
  self.view.keycardAuthSuccess(encryptionPublicKey)

{.pop.}