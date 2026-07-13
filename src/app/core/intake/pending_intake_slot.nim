## Pending intake slot — the App Group hand-off buffer between the iOS share
## extension and the host app (see mobile/ios/shareExtension/).
##
## Single file, last-wins: the extension overwrites `share.json` in the slot
## directory; the host app takes (reads + clears) it when it comes to the
## foreground. The extension wakes the host via the unsupported responder-chain
## openURL workaround (ShareIntakeWakeUrl); if that wake fails, the payload
## simply stays in the file and is delivered on the next manual app open —
## degraded UX, no data loss.
##
## Kept free of Qt/chronicles imports so the semantics are unit-testable on any
## platform (test/nim/pending_intake_slot_test.nim). The iOS-only slot directory
## comes from StatusQ (statusq_shareintake_pending_dir); on platforms without an
## App Group container the dir is empty and the slot is inactive.

import std/os

const
  PendingIntakeFileName* = "share.json"
  ShareIntakeWakeUrl* = "status-app://share-intake"
    ## Wake ping sent by the share extension via openURL. Carries no data — the
    ## payload travels through the slot file. Must match kWakeUrl in
    ## mobile/ios/shareExtension/ShareViewController.m.

type PendingIntakeSlot* = ref object
  slotDir: string

proc newPendingIntakeSlot*(slotDir: string): PendingIntakeSlot =
  ## An empty `slotDir` (no App Group container on this platform/build) yields
  ## an inactive slot: writes are dropped, take() always returns "".
  PendingIntakeSlot(slotDir: slotDir)

proc isActive*(self: PendingIntakeSlot): bool =
  self.slotDir.len > 0

proc filePath*(self: PendingIntakeSlot): string =
  if not self.isActive():
    return ""
  self.slotDir / PendingIntakeFileName

proc write*(self: PendingIntakeSlot, payload: string) =
  ## Overwrites any previous payload (last-wins). The iOS extension writes the
  ## same file natively; this Nim writer exists for tests and future
  ## non-extension intake producers. IO failures are swallowed — losing a slot
  ## write must never take the app down.
  if not self.isActive():
    return
  try:
    createDir(self.slotDir)
    writeFile(self.filePath(), payload)
  except CatchableError:
    discard

proc peek*(self: PendingIntakeSlot): string =
  ## Reads the pending payload without clearing it; "" when there is none.
  ## Used by the fresh-launch cache sweep to learn which cached image copies
  ## the still-pending payload references before delivery.
  let path = self.filePath()
  if not self.isActive() or not fileExists(path):
    return ""
  try:
    result = readFile(path)
  except CatchableError:
    result = ""

proc take*(self: PendingIntakeSlot): string =
  ## Reads and clears the pending payload; "" when there is none.
  let path = self.filePath()
  if not self.isActive() or not fileExists(path):
    return ""
  try:
    result = readFile(path)
    removeFile(path)
  except CatchableError:
    result = ""
