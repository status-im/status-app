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

  test "peek reads the payload without clearing it":
    # The fresh-launch cache sweep must know which cached image copies the
    # still-pending payload references, without consuming the payload.
    let slot = newPendingIntakeSlot(slotDir)
    slot.write("payload")
    check slot.peek() == "payload"
    check slot.take() == "payload"

  test "peek on an empty or inactive slot returns empty string":
    let slot = newPendingIntakeSlot(slotDir)
    check slot.peek() == ""
    check newPendingIntakeSlot("").peek() == ""

  test "payload survives across slot instances (writer and reader are different processes)":
    let writer = newPendingIntakeSlot(slotDir)
    writer.write("from-extension")
    let reader = newPendingIntakeSlot(slotDir)
    check reader.take() == "from-extension"

  test "wake recognition accepts any variant scheme with the share-intake authority":
    # Each iOS app variant wakes itself through its own bundle-id-derived
    # scheme (issue #48: the shared status-app scheme let a co-installed
    # Status PR hijack the wake), so recognition keys on the share-intake
    # authority, not the scheme.
    check isShareIntakeWakeUrl(ShareIntakeWakeUrl)
    check isShareIntakeWakeUrl("app.status.mobile://share-intake")
    check isShareIntakeWakeUrl("app.status.mobile.pr://share-intake")
    # onUrlActivated strips surrounding whitespace before routing
    check isShareIntakeWakeUrl("  status-app://share-intake\n")
    # trailing path/query/fragment keep the wake meaning
    check isShareIntakeWakeUrl("status-app://share-intake/")
    check isShareIntakeWakeUrl("app.status.mobile://share-intake?src=ext")

  test "wake recognition rejects non-wake urls":
    check not isShareIntakeWakeUrl("")
    check not isShareIntakeWakeUrl("share-intake")
    check not isShareIntakeWakeUrl("://share-intake")
    check not isShareIntakeWakeUrl("status-app://c/community")
    check not isShareIntakeWakeUrl("https://status.app/share-intake")
    check not isShareIntakeWakeUrl("https://share-intake.example.com")
    check not isShareIntakeWakeUrl("status-app://share-intakefoo")
