## Unit tests for the prepared Attachments release helper
## (app/core/prepared_attachments). AttachmentPreparer writes prepared copies
## of attached images to its own temporary directory; the image send deletes
## them once sent, and must never touch files outside that exact directory
## (originals sent as they are travel through the same image-send task).

import unittest, os, strutils
import app/core/prepared_attachments

suite "prepared_attachments":
  setup:
    let baseDir = getTempDir() / "prepared_attachments_test"
    removeDir(baseDir)
    let preparedDir = baseDir / "status-attachments"
    createDir(preparedDir)

  teardown:
    removeDir(baseDir)

  test "releases files directly inside the prepared directory":
    let first = preparedDir / "a.jpg"
    let second = preparedDir / "b.png"
    writeFile(first, "img")
    writeFile(second, "img")

    releasePreparedAttachments(@[first, second], preparedDir)

    check not fileExists(first)
    check not fileExists(second)

  test "matches paths with forward slashes and a trailing separator":
    let file = preparedDir / "c.jpg"
    writeFile(file, "img")

    releasePreparedAttachments(@[file.replace(DirSep, '/')], preparedDir & "/")

    check not fileExists(file)

  test "files outside the prepared directory are left alone":
    let userFile = baseDir / "keep.jpg"
    let nestedDir = preparedDir / "nested"
    createDir(nestedDir)
    let nested = nestedDir / "keep.jpg"
    let lookalikeDir = baseDir / "other" / "status-attachments"
    createDir(lookalikeDir)
    let lookalike = lookalikeDir / "keep.jpg"
    for f in [userFile, nested, lookalike]:
      writeFile(f, "img")

    releasePreparedAttachments(@[userFile, nested, lookalike], preparedDir)

    check fileExists(userFile)
    check fileExists(nested)
    check fileExists(lookalike)

  test "an unset directory releases nothing":
    let file = preparedDir / "d.jpg"
    writeFile(file, "img")

    releasePreparedAttachments(@[file], "")

    check fileExists(file)

  test "missing files and empty input are ignored":
    releasePreparedAttachments(@[], preparedDir)
    releasePreparedAttachments(@[preparedDir / "missing.jpg"], preparedDir)
