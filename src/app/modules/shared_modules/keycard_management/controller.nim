import chronicles
import io_interface

import app/core/eventemitter
import app_service/service/keycardV2/service as keycard_serviceV2

logScope:
  topics = "keycard-management-module-controller"

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    keycardServiceV2: keycard_serviceV2.Service

proc newController*(delegate: io_interface.AccessInterface,
  events: EventEmitter,
  keycardServiceV2: keycard_serviceV2.Service):
  Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events
  result.keycardServiceV2 = keycardServiceV2

proc delete*(self: Controller) =
  discard

proc init*(self: Controller) =
  self.events.on(SIGNAL_KEYCARD_STATE_UPDATED) do(e: Args):
    let args = KeycardEventArg(e)
    self.delegate.onKeycardStateUpdated(args.keycardEvent)

  self.events.on(SIGNAL_KEYCARD_GET_KEYCARD_METADATA_FINISHED) do(e: Args):
    let args = KeycardGetKeycardMetadataArgs(e)
    self.delegate.onKeycardGetMetadataFinished(args.metadata, args.error)

proc startGetMetadata*(self: Controller, pin: string) =
  self.keycardServiceV2.asyncGetKeycardMetadata(pin)

proc stopKeycardAction*(self: Controller) =
  self.keycardServiceV2.asyncStop()
