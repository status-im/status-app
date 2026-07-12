## Cache lifecycle for shared media (see CONTEXT.md -> "External intake").
##
## The platform layer copies shared image streams into an app-private cache
## directory named `share-intake` immediately at receipt (OS read grants on
## content URIs expire; the intake must hold copies, never OS-managed URIs).
## Those copies are deleted after the share is sent or cancelled — and, for a
## pending share replaced last-wins, when it is discarded.
##
## Deletion is guarded to files inside a `share-intake` directory: the same
## image-send path also carries user-owned files (regular picker sends), which
## must never be touched.

import std/os

const ShareIntakeCacheDirName* = "share-intake"

proc isShareIntakeCachedFile*(path: string): bool =
  ## True only for files directly inside a `share-intake` directory — the only
  ## files the cache lifecycle owns.
  extractFilename(parentDir(path)) == ShareIntakeCacheDirName

proc releaseCachedShareFiles*(imagePaths: seq[string]) =
  ## Best-effort deletion of share-intake cached copies; paths outside a
  ## `share-intake` directory and already-missing files are ignored.
  for path in imagePaths:
    if isShareIntakeCachedFile(path):
      try:
        removeFile(path)
      except CatchableError:
        discard
