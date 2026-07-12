## Unit tests for the share-intake cache lifecycle helper
## (app/core/intake/share_intake_cache). The platform layer copies shared
## media into an app-private `share-intake` cache directory at receipt;
## releaseCachedShareFiles deletes those copies after send or cancel, and must
## never touch files outside a `share-intake` directory (regular picker sends
## pass user-owned paths through the same image-send task).

import unittest, os
import app/core/intake/share_intake_cache

suite "share_intake_cache":
  setup:
    let baseDir = getTempDir() / "share_intake_cache_test"
    removeDir(baseDir)
    let cacheDir = baseDir / ShareIntakeCacheDirName
    createDir(cacheDir)

  teardown:
    removeDir(baseDir)

  test "releases cached copies inside a share-intake directory":
    let first = cacheDir / "a.png"
    let second = cacheDir / "b.jpg"
    writeFile(first, "img")
    writeFile(second, "img")

    releaseCachedShareFiles(@[first, second])

    check not fileExists(first)
    check not fileExists(second)

  test "files outside a share-intake directory are left alone":
    let userFile = baseDir / "keep.png"
    writeFile(userFile, "img")

    releaseCachedShareFiles(@[userFile])

    check fileExists(userFile)

  test "missing files and empty input are ignored":
    releaseCachedShareFiles(@[cacheDir / "already-gone.png"])
    releaseCachedShareFiles(@[])
    check true

  test "decodes the image-paths wire format":
    check parseImagePathsJson("""["/cache/share-intake/a.png","/b.jpg"]""") ==
      @["/cache/share-intake/a.png", "/b.jpg"]

  test "empty and malformed image-paths payloads decode to no images":
    check parseImagePathsJson("").len == 0
    check parseImagePathsJson("[]").len == 0
    check parseImagePathsJson("not json").len == 0
