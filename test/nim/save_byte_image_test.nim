## Tests for save_byte_image_to_file (app_service/common/utils).
## Exercises the data-URI base64 decode + temporary QImage save path and the load-failure path.
## Requires the Qt runtime (QImage / QStandardPaths / QUuid), like qsettings_test.

import unittest, os, strutils
import app_service/common/utils
import seaqt/qstandardpaths

suite "save_byte_image_to_file":

  # Valid 1x1 red PNG (8-bit RGB), base64-encoded.
  const onePxPngB64 =
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC"

  test "data-URI base64 image is decoded into the temporary directory":
    let dataUri = "data:image/png;base64," & onePxPngB64
    let savedPath = save_byte_image_to_file(dataUri)
    check savedPath.len > 0
    check savedPath.endsWith(".png")
    check fileExists(savedPath)
    check parentDir(savedPath) == QStandardPaths.writableLocation(
      QStandardPathsStandardLocationEnum.TempLocation)
    # Clean up the temporary file created by this direct helper test.
    if fileExists(savedPath):
      removeFile(savedPath)

  test "unloadable input returns empty string":
    # A path that does not exist (and is not a data URI) cannot be loaded.
    check save_byte_image_to_file(getTempDir() / "does_not_exist_save_byte_image.xyz") == ""

  test "empty input returns empty string":
    check save_byte_image_to_file("") == ""
