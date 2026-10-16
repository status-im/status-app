## ZXing (nim-qrscan's decoder) reports decode problems by throwing C++
## exceptions it catches itself, e.g. BitSource::readBits on a damaged QR code.
## That only works if the app binary keeps its unwind info: with
## `-Wl,-no_compact_unwind` on arm64 macOS every such throw aborted the app.
## This test is built with the app's config.nims, so it covers the app's flags.

import std/[strutils, unittest]
import qrscan/zxing

suite "ZXing error paths in the app binary":
  test "an exception thrown and caught inside ZXing doesn't abort":
    # Unknown name: ZXing throws std::invalid_argument internally; its C API
    # catches it and records the message.
    discard ZXing_BarcodeFormatFromString("not-a-format")
    let msg = ZXing_LastErrorMsg()
    check msg != nil
    if msg != nil:
      check "not a valid barcode format" in $msg
      ZXing_free(msg)
