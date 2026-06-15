import nimqml, chronicles, strutils

import io_interface
import view, controller
import app/core/eventemitter
import app/modules/shared_models/keypair_item

import app_service/common/wallet_constants as wallet_constants
import app_service/common/utils as common_utils
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

proc toCanonicalSignature(r, s, v: string): string =
  let
    rClean = common_utils.removeHexPrefix(r)
    sClean = common_utils.removeHexPrefix(s)
    vClean = common_utils.removeHexPrefix(v)
  if rClean.len != wallet_constants.SIGNATURE_R_LEN or
    sClean.len != wallet_constants.SIGNATURE_S_LEN or
    vClean.len != wallet_constants.SIGNATURE_V_LEN:
      error "unexpected signature length from signMessage", r=rClean, s=sClean, v=vClean
      return ""
  try:
    let vInt = parseHexInt(vClean)
    ## Aligning signature with v parameter in yellow-paper form (27/28)
    let canonicalV = if vInt < 27: vInt + 27 else: vInt
    return "0x" & rClean & sClean & toLowerAscii(toHex(canonicalV, 2))
  except ValueError:
    error "failed to parse v", msg = vClean

method signMessage*[T](self: Module[T], address: string, password: string, txHash: string): string =
  let (res, err) = self.controller.signMessage(address, password, txHash)
  if err.len > 0:
    error "signMessage failed", error=err
    return ""
  let (r, s, v) = common_utils.getRSVFromSignature(res)
  return toCanonicalSignature(r, s, v)

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
  self.view.keycardSignSuccess(toCanonicalSignature(signature.r, signature.s, toHex(signature.v, wallet_constants.SIGNATURE_V_LEN)))

{.pop.}
