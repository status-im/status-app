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
##
## Also owns the wire format the paths travel in across the Qt signal/slot
## boundary: a JSON array of absolute paths.

import std/[json, os]
import chronicles

const ShareIntakeCacheDirName* = "share-intake"

proc parseImagePathsJson*(imagePathsJson: string): seq[string] =
  ## Tolerant decode of the image-paths wire format (a JSON array of absolute
  ## paths); a malformed payload is logged and treated as no images — it must
  ## never take the app down.
  if imagePathsJson.len == 0:
    return @[]
  try:
    for pathNode in parseJson(imagePathsJson).getElems():
      result.add(pathNode.getStr())
  except CatchableError:
    warn "share intake image paths payload is not valid JSON", imagePathsJson
    return @[]

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
