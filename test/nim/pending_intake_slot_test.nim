## Unit tests for the pending intake slot (app/core/intake/pending_intake_slot):
## the last-wins, single-payload file buffer used for the iOS share-extension
## App Group hand-off. The extension writes the same file natively
## (mobile/ios/shareExtension/ShareViewController.m); these tests pin down the
## host-side semantics: take() delivers exactly once, last write wins, and an
## undelivered payload survives until the next take (degraded wake fallback).

import unittest, os
import app/core/intake/pending_intake_slot

suite "pending_intake_slot":
  setup:
    let slotDir = getTempDir() / "pending_intake_slot_test"
    removeDir(slotDir)

  teardown:
    removeDir(slotDir)

  test "slot without a container dir is inactive and never delivers":
    let slot = newPendingIntakeSlot("")
    check not slot.isActive()
    check slot.filePath() == ""
    slot.write("ignored")
    check slot.take() == ""

  test "write then take delivers the payload":
    let slot = newPendingIntakeSlot(slotDir)
    check slot.isActive()
    slot.write("""{"type":"share","text":"hello"}""")
    check slot.take() == """{"type":"share","text":"hello"}"""

  test "take clears the slot - payload is delivered exactly once":
    let slot = newPendingIntakeSlot(slotDir)
    slot.write("payload")
    check slot.take() == "payload"
    check slot.take() == ""
    check not fileExists(slot.filePath())

  test "second write overwrites the first (last-wins)":
    let slot = newPendingIntakeSlot(slotDir)
    slot.write("first")
    slot.write("second")
    check slot.take() == "second"
    check slot.take() == ""

  test "take on an empty slot returns empty string":
    let slot = newPendingIntakeSlot(slotDir)
    check slot.take() == ""

  test "payload survives across slot instances (writer and reader are different processes)":
    let writer = newPendingIntakeSlot(slotDir)
    writer.write("from-extension")
    let reader = newPendingIntakeSlot(slotDir)
    check reader.take() == "from-extension"
