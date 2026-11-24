## Prepared Attachments: the resized/compressed copies of attached images that
## AttachmentPreparer (StatusQ) writes to a temporary directory the app owns.
## The image send carries them to status-go, which reads them during the send,
## so they are deleted once the send is done.
##
## Deletion is guarded to files directly inside that exact directory: the same
## image-send path also carries user-owned files (originals sent as they are,
## share-intake copies), which must never be touched here.

import std/os

var preparedAttachmentsDir: string

proc setPreparedAttachmentsDir*(dir: string) =
  ## Set once at startup, on the main thread, before any send.
  preparedAttachmentsDir = dir

proc getPreparedAttachmentsDir*(): string =
  preparedAttachmentsDir

proc isPreparedAttachment*(path, dir: string): bool =
  ## True only for files directly inside `dir` (empty `dir` matches nothing).
  if dir.len == 0 or path.len == 0:
    return false
  cmpPaths(normalizedPath(parentDir(path)), normalizedPath(dir)) == 0

proc releasePreparedAttachments*(paths: seq[string], dir: string) =
  ## Best-effort deletion of the prepared Attachments among `paths`; other
  ## paths and already-missing files are ignored.
  for path in paths:
    if isPreparedAttachment(path, dir):
      discard tryRemoveFile(path)
