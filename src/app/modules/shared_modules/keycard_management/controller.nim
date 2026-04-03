import chronicles
import uuids
import io_interface

import app/core/eventemitter
import app_service/service/keycardV2/service as keycard_serviceV2

logScope:
  topics = "keycard-management-module-controller"

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter
    connectionIds: seq[UUID]
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
  for id in self.connectionIds:
    self.events.disconnect(id)

proc init*(self: Controller) =
  var handlerId = self.events.onWithUUID(SIGNAL_KEYCARD_STATE_UPDATED) do(e: Args):
    let args = KeycardEventArg(e)
    self.delegate.onKeycardStateUpdated(args.keycardEvent)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_KEYCARD_GET_KEYCARD_METADATA_FINISHED) do(e: Args):
    let args = KeycardGetKeycardMetadataArgs(e)
    self.delegate.onKeycardGetMetadataFinished(args.metadata, args.error)
  self.connectionIds.add(handlerId)

  handlerId = self.events.onWithUUID(SIGNAL_KEYCARD_FACTORY_RESET_KEYCARD_FINISHED) do(e: Args):
    let args = KeycardErrorArg(e)
    self.delegate.onKeycardFactoryResetFinished(args.error)
  self.connectionIds.add(handlerId)

proc startGetMetadata*(self: Controller, pin: string) =
  self.keycardServiceV2.asyncGetKeycardMetadata(pin)

proc startFactoryReset*(self: Controller, keycardUid: string) =
  self.keycardServiceV2.asyncFactoryResetKeycard(keycardUid)

proc stopKeycardAction*(self: Controller) =
  self.keycardServiceV2.asyncStop()
