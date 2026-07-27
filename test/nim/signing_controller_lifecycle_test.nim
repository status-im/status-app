## Regression: signing Controller.init registers permanent EventEmitter
## handlers, but delete() is a no-op — each create/destroy cycle leaks handlers.

import unittest

import app/core/eventemitter
import app/modules/shared_modules/signing/[io_interface, controller]
import app_service/service/keycardV2/service as keycard_serviceV2
import app_service/service/keycardV2/dto as keycard_dto

type
  FakeSigningDelegate = ref object of AccessInterface
    stateUpdates: int
    signFinished: int

method delete*(self: FakeSigningDelegate) =
  discard

method onKeycardStateUpdated*(self: FakeSigningDelegate, kcEvent: keycard_dto.KeycardEventDto) =
  inc self.stateUpdates

method onKeycardSignFinished*(self: FakeSigningDelegate,
    signature: keycard_dto.KeycardSignatureDto, error: string) =
  inc self.signFinished

suite "signing controller lifecycle":

  test "delete disconnects keycard state handlers":
    let events = createEventEmitter()
    let delegate = FakeSigningDelegate()
    let ctrl = newController(delegate, events, nil, nil, nil, nil)
    ctrl.init()
    ctrl.delete()

    events.emit(SIGNAL_KEYCARD_STATE_UPDATED, KeycardEventArg(
      keycardEvent: KeycardEventDto()))

    check delegate.stateUpdates == 0

  test "delete disconnects sign finished handlers":
    let events = createEventEmitter()
    let delegate = FakeSigningDelegate()
    let ctrl = newController(delegate, events, nil, nil, nil, nil)
    ctrl.init()
    ctrl.delete()

    events.emit(SIGNAL_KEYCARD_SIGN_FINISHED, KeycardSignArgs(
      signature: KeycardSignatureDto(), error: ""))

    check delegate.signFinished == 0

  test "recreate after delete does not stack state handlers":
    let events = createEventEmitter()
    let first = FakeSigningDelegate()
    let second = FakeSigningDelegate()

    let ctrl1 = newController(first, events, nil, nil, nil, nil)
    ctrl1.init()
    ctrl1.delete()

    let ctrl2 = newController(second, events, nil, nil, nil, nil)
    ctrl2.init()

    events.emit(SIGNAL_KEYCARD_STATE_UPDATED, KeycardEventArg(
      keycardEvent: KeycardEventDto()))

    check first.stateUpdates == 0
    check second.stateUpdates == 1
