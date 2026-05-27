import nimqml, chronicles

import io_interface
import view, controller
import app/core/eventemitter
import app/modules/shared_models/keypair_item

import app_service/service/accounts/service as accounts_service
import app_service/service/wallet_account/service as wallet_account_service
import app_service/service/transaction/service as transaction_service
import app_service/service/keycardV2/service as keycard_serviceV2

export io_interface

logScope:
  topics = "signing-module"

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
  transactionService: transaction_service.Service,
  keycardServiceV2: keycard_serviceV2.Service):
  Module[T] =
  result = Module[T]()
  result.delegate = delegate
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, events, accountsService, walletAccountService, transactionService, keycardServiceV2)
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

method signMessage*[T](self: Module[T], address: string, password: string, txHash: string): string =
  let (res, err) = self.controller.signMessage(address, password, txHash)
  if err.len > 0:
    error "signMessage failed", error=err
    return ""
  return res

method isKeypairMigratedToColdWallet*[T](self: Module[T], keyUid: string): bool =
  return self.controller.isKeypairMigratedToColdWallet(keyUid)

method buildKeyPairForProcessing*[T](self: Module[T], keyUid: string): KeyPairItem =
  let item = self.controller.buildKeyPairForProcessing(keyUid)
  if not item.isNil:
    self.view.setKeyPairForProcessing(item)
  return item

method startKeycardSigning*[T](self: Module[T], keyUid: string, pin: string, txHash: string, path: string) =
  self.controller.startKeycardSigning(keyUid, pin, txHash, path)

method stopKeycardSigning*[T](self: Module[T]) =
  self.controller.stopKeycardSigning()

method onKeycardStateUpdated*[T](self: Module[T], kcEvent: KeycardEventDto) =
  self.view.setKeycardState($kcEvent.stateString)
  self.view.setRemainingPinAttempts(kcEvent.keycardStatus.remainingAttemptsPIN)

method onKeycardSignFinished*[T](self: Module[T], signature: KeycardSignatureDto, error: string) =
  if error.len > 0:
    error "keycard sign error", error=error
    self.view.keycardSignError(error)
    return
  self.view.keycardSignSuccess(signature.r, signature.s, signature.v)

{.pop.}
