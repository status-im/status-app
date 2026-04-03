import nimqml, chronicles, json

import io_interface
import view, controller
import app/core/eventemitter

import app_service/service/keycardV2/service as keycard_serviceV2

export io_interface

logScope:
  topics = "keycard-management-module"

type
  Module*[T: io_interface.DelegateInterface] = ref object of io_interface.AccessInterface
    delegate: T
    view: View
    viewVariant: QVariant
    controller: Controller

proc newModule*[T](delegate: T,
  events: EventEmitter,
  keycardServiceV2: keycard_serviceV2.Service):
  Module[T] =
  result = Module[T]()
  result.delegate = delegate
  result.view = view.newView(result)
  result.viewVariant = newQVariant(result.view)
  result.controller = controller.newController(result, events, keycardServiceV2)
  result.controller.init()

{.push warning[Deprecated]: off.}

method delete*[T](self: Module[T]) =
  self.view.delete
  self.viewVariant.delete
  self.controller.delete

method getModuleAsVariant*[T](self: Module[T]): QVariant =
  return self.viewVariant

method startGetMetadata*[T](self: Module[T], pin: string) =
  self.controller.startGetMetadata(pin)

method stopKeycardAction*[T](self: Module[T]) =
  self.controller.stopKeycardAction()

method onKeycardStateUpdated*[T](self: Module[T], kcEvent: KeycardEventDto) =
  self.view.setKeycardState($kcEvent.stateString)
  self.view.setRemainingPinAttempts(kcEvent.keycardStatus.remainingAttemptsPIN)
  self.view.setRemainingPukAttempts(kcEvent.keycardStatus.remainingAttemptsPUK)
  self.view.setAvailableSlots(kcEvent.keycardInfo.availableSlots)
  self.view.setKeyUid(kcEvent.keycardInfo.keyUID)
  self.view.setKeycardUid(kcEvent.keycardInfo.instanceUID)

method onKeycardGetMetadataFinished*[T](self: Module[T], metadata: CardMetadataDto, error: string) =
  if error.len > 0:
    error "keycard get metadata error", error=error
    self.view.keycardGetMetadataError(error)
    return
  self.view.setCardMetadataName(metadata.name)
  var walletsJson = newJArray()
  for acc in metadata.walletAccounts:
    walletsJson.add(%*{
      "path": acc.path,
      "address": acc.address,
      "publicKey": acc.publicKey,
    })
  self.view.setCardMetadataWalletAccountsJson($walletsJson)
  self.view.keycardGetMetadataSuccess()

method startFactoryReset*[T](self: Module[T], keycardUid: string) =
  self.controller.startFactoryReset(keycardUid)

method onKeycardFactoryResetFinished*[T](self: Module[T], error: string) =
  if error.len > 0:
    error "keycard factory reset error", error=error
    self.view.keycardFactoryResetError(error)
    return
  self.view.keycardFactoryResetSuccess()

{.pop.}
