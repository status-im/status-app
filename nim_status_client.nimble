# Package

version       = "0.1.0"
author        = "Status Research & Development GmbH"
description   = "Desktop client for the Status Network built with Nim and Qt"
license       = "MPL2"
srcDir        = "src"
bin           = @["nim_status_client"]
skipExt       = @["nim"]

# Deps
requires "nim >= 1.0.0", "stint", "nimcrypto >= 0.4.11", "uuids >= 0.1.10"
