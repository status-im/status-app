import nimqml, chronicles

import io_interface
import view, controller
import app/core/eventemitter
import app/modules/shared_models/keypair_item

import app/global/global_singleton
from app_service/common/account_constants import PATH_ENCRYPTION
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

method isKeypairMigratedToColdWallet*[T](self: Module[T], keyUid: string): bool =
  return self.controller.isKeypairMigratedToColdWallet(keyUid)

method buildKeyPairForProcessing*[T](self: Module[T], keyUid: string): KeyPairItem =
  let item = self.controller.buildKeyPairForProcessing(keyUid)
  if not item.isNil:
    self.view.setKeyPairForProcessing(item)
  return item

method startKeycardAuthentication*[T](self: Module[T], keyUid: string, pin: string, exportChatKey: bool) =
  let
    targetKeyUid = if keyUid.len > 0: keyUid
                   else: singletonInstance.userProfile.getKeyUid()
    exportPrivate = true
    exportMasterAddr = false
  var paths = @[account_constants.PATH_ENCRYPTION]
  if exportChatKey:
    paths.add(account_constants.PATH_WHISPER)
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
  if exportedPublicKeys.keys.len == 0:
    error "exporting public keys error", error="expected at least 1 key, got 0"
    self.view.keycardAuthError("failed to export keys from the keycard")
    return
  # order in response is guaranteed to be the same as the order in the request (PATH_ENCRYPTION first, PATH_WHISPER second)
  let encryptionPublicKey = exportedPublicKeys.keys[0].publicKey
  var chatPrivateKey = ""
  if exportedPublicKeys.keys.len > 1:
    chatPrivateKey = exportedPublicKeys.keys[1].privateKey
  self.view.keycardAuthSuccess(encryptionPublicKey, chatPrivateKey)

{.pop.}