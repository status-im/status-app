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

proc sweepShareIntakeCacheDir*(cacheDir: string, referencedPaths: seq[string]) =
  ## Fresh-launch cleanup of cached copies a previous run left behind (killed
  ## before the send/cancel release could run). Deletes every file directly
  ## inside the given `share-intake` cache directory except the ones still
  ## referenced — on iOS the pending intake slot payload's copies must survive
  ## until delivery (a logged-out share survives login and app restarts).
  ## Guarded to directories actually named `share-intake`; best-effort, IO
  ## failures must never take the app down.
  if extractFilename(cacheDir) != ShareIntakeCacheDirName or not dirExists(cacheDir):
    return
  try:
    for kind, path in walkDir(cacheDir):
      if kind == pcFile and path notin referencedPaths:
        try:
          removeFile(path)
        except CatchableError:
          discard
  except CatchableError:
    discard

proc releaseCachedShareFiles*(imagePaths: seq[string]) =
  ## Best-effort deletion of share-intake cached copies; paths outside a
  ## `share-intake` directory and already-missing files are ignored.
  for path in imagePaths:
    if isShareIntakeCachedFile(path):
      try:
        removeFile(path)
      except CatchableError:
        discard
