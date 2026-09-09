## Regression tests for the dApp estimated-time fee path (wallet_connect
## asyncGetEstimatedTimeTask): a dApp transaction's maxFeePerGas/gasPrice is
## already denominated in wei and must reach getTransactionEstimatedTimeV2
## unscaled, while the gwei values reported by eth_suggestedFees are converted
## to wei exactly once. The task itself is `include`d into the wallet_connect
## service (not importable), so these cover the conversion helpers it calls
## verbatim — normalizedWeiHexValue / gweiToWeiHexValue.

import unittest, strutils

import app_service/service/eth/utils as eth_utils

suite "eth_utils - fee hex conversion (dApp estimated-time path)":

  test "a supplied wei hex value passes through unscaled":
    # 0x2540be400 == 10^10 wei == 10 gwei; multiplying it by 1e9 again (the
    # old bug) would claim a 10-billion-gwei fee
    check eth_utils.normalizedWeiHexValue("0x2540be400") == "0x2540be400"

  test "normalization canonicalizes form only, never the value":
    check eth_utils.normalizedWeiHexValue("0x0002540BE400") == "0x2540be400"
    check eth_utils.normalizedWeiHexValue("0x0") == "0x0"

  test "the suggested gwei fee converts to wei exactly once":
    check eth_utils.gweiToWeiHexValue(10.0) == "0x2540be400"   # 10 gwei
    check eth_utils.gweiToWeiHexValue(1.5) == "0x59682f00"     # 1.5 gwei
    check eth_utils.gweiToWeiHexValue(0.0) == "0x0"

  test "wei values beyond int64 survive without overflow":
    # 2^70 wei — parseHexInt/int64 (the old path) cannot represent this
    check eth_utils.normalizedWeiHexValue("0x400000000000000000") ==
      "0x400000000000000000"
    # the full UInt256 range round-trips
    let maxHex = "0x" & repeat('f', 64)
    check eth_utils.normalizedWeiHexValue(maxHex) == maxHex

  test "leading zeros never count against the 256-bit width":
    # 65 digits, but only one significant — a padded zero is still zero
    check eth_utils.normalizedWeiHexValue("0x" & repeat('0', 65)) == "0x0"
    check eth_utils.normalizedWeiHexValue("0x" & repeat('0', 63) & "2540be400") ==
      "0x2540be400"

  test "malformed input raises instead of silently degrading":
    expect ValueError:
      discard eth_utils.normalizedWeiHexValue("0xnot-a-number")
    # bare prefix must not read as zero
    expect ValueError:
      discard eth_utils.normalizedWeiHexValue("0x")
    expect ValueError:
      discard eth_utils.normalizedWeiHexValue("")
    # no prefix, no deal — a bare quantity is ambiguous
    expect ValueError:
      discard eth_utils.normalizedWeiHexValue("2540be400")

  test "values wider than 256 bits are rejected, not wrapped":
    # 65 significant digits: stint's fromHex would reduce this mod 2^256 to
    # ZERO — i.e. a huge malformed fee silently becoming the lowest one
    expect ValueError:
      discard eth_utils.normalizedWeiHexValue("0x1" & repeat('0', 64))
    expect ValueError:
      discard eth_utils.normalizedWeiHexValue("0x" & repeat('f', 65))
