## The backend signal epoch gate accepts only signals stamped with the accepted
## epoch; signals of an earlier backend session or without an epoch are rejected.

import unittest, strutils
import app/core/signal_epoch

suite "signal epoch":

  test "reads the epoch right after the type":
    check signalEpochOf("""{"type":"node.ready","epoch":7,"event":{},"timestamp":1}""") == 7
    check signalEpochOf("""{"type":"x","epoch":1234567890123456789,"event":null}""") == 1234567890123456789'u64

  test "an epoch too long for uint64 is none":
    check signalEpochOf("""{"type":"x","epoch":123456789012345678901,"event":{}}""") == NoEpoch

  test "a signal without an epoch has none":
    check signalEpochOf("""{"type":"node.ready","event":{}}""") == NoEpoch
    check signalEpochOf("""{"type":"x","epoch":,"event":{}}""") == NoEpoch
    check signalEpochOf("") == NoEpoch

  test "an epoch key inside the event is not the envelope's":
    check signalEpochOf("""{"type":"messages.new","event":{"a":0,"epoch":7}}""") == NoEpoch
    check signalEpochOf("""{"event":{},"type":"x","epoch":7}""") == NoEpoch
    check signalEpochOf("""{"type":"x","epochs":7,"event":{}}""") == NoEpoch

  test "the epoch must end at a delimiter":
    check signalEpochOf("""{"type":"x","epoch":7x,"event":{}}""") == NoEpoch
    check signalEpochOf("""{"type":"x","epoch":7""") == NoEpoch
    check signalEpochOf("""{"type":"x","epoch":7}""") == 7

  test "an epoch key inside a large event payload is not scanned":
    let signal = """{"type":"messages.new","event":{"text":"""" & 'a'.repeat(1000) &
      """","epoch":3}}"""
    check signalEpochOf(signal) == NoEpoch

suite "signal gate":

  test "routes by epoch and receiver":
    var gate = initSignalGate(10)
    check gate.route(2, 2, "a", hasReceiver = true) == SignalRoute.Deliver
    check gate.route(1, 2, "old", hasReceiver = true) == SignalRoute.Drop
    check gate.route(NoEpoch, 2, "none", hasReceiver = true) == SignalRoute.Drop
    check gate.route(2, 2, "no receiver", hasReceiver = false) == SignalRoute.Hold
    check gate.route(3, 2, "next session", hasReceiver = true) == SignalRoute.Hold
    check gate.heldCount == 2

  test "signals of the next epoch emitted during logout are delivered once it is accepted":
    var gate = initSignalGate(10)
    # Logout from epoch 1: node.stopped (1), then the re-initialized backend (2) emits
    # before the client learns that epoch 2 is current.
    check gate.route(1, 1, "node.stopped", hasReceiver = false) == SignalRoute.Hold
    check gate.route(2, 1, "mediaserver.started", hasReceiver = false) == SignalRoute.Hold
    check gate.takeDeliverable(2) == @["mediaserver.started"]
    check gate.heldCount == 0

  test "signals of a session whose activity stopped are dropped, not held":
    var gate = initSignalGate(10)
    check gate.route(1, 1, "late", hasReceiver = false, endedEpoch = 1) == SignalRoute.Drop
    check gate.route(2, 1, "next session", hasReceiver = false, endedEpoch = 1) == SignalRoute.Hold
    check gate.heldCount == 1

  test "a late signal of the ended session never reaches the next one":
    var gate = initSignalGate(10)
    check gate.route(1, 2, "late", hasReceiver = true) == SignalRoute.Drop
    check gate.takeDeliverable(2).len == 0

  test "held signals of a later epoch stay held":
    var gate = initSignalGate(10)
    discard gate.route(2, 2, "now", hasReceiver = false)
    discard gate.route(3, 2, "later", hasReceiver = false)
    check gate.takeDeliverable(2) == @["now"]
    check gate.takeDeliverable(3) == @["later"]

  test "the hold buffer is bounded, dropping the oldest":
    var gate = initSignalGate(2)
    for s in ["a", "b", "c"]:
      discard gate.route(1, 1, s, hasReceiver = false)
    check gate.takeDeliverable(1) == @["b", "c"]
