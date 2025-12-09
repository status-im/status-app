import ./io_interface
import app/core/eventemitter
import app_service/service/keycardV2/service as keycard_serviceV2

type
  Controller* = ref object of RootObj
    delegate: io_interface.AccessInterface
    events: EventEmitter

proc newController*(
  delegate: io_interface.AccessInterface,
  events: EventEmitter
): Controller =
  result = Controller()
  result.delegate = delegate
  result.events = events

proc delete*(self: Controller) =
  discard

proc init*(self: Controller) =
  # Listen to channel state changes
  self.events.on(keycard_serviceV2.SIGNAL_KEYCARD_CHANNEL_STATE_UPDATED) do(e: Args):
    let args = keycard_serviceV2.KeycardChannelStateArg(e)
    self.delegate.setKeycardChannelState(args.state)


