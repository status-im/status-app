## Custom gas travels as decimal text and reaches status-go as a uint64, up to 2^32 - 1.

import unittest, json

import app_service/service/eth/utils as eth_utils

suite "eth_utils - parseGasAmount":

  test "values beyond int32 survive":
    check eth_utils.parseGasAmount("2147483647") == 2_147_483_647'u64  # 2^31 - 1
    check eth_utils.parseGasAmount("2147483648") == 2_147_483_648'u64  # 2^31
    check eth_utils.parseGasAmount("3000000000") == 3_000_000_000'u64
    check eth_utils.parseGasAmount("4294967295") == eth_utils.MaxTxGasAmount  # 2^32 - 1

  test "ordinary amounts, including post-fork sub-21000 ones":
    check eth_utils.parseGasAmount("12000") == 12_000'u64
    check eth_utils.parseGasAmount("21000") == 21_000'u64
    check eth_utils.parseGasAmount("217760") == 217_760'u64

  test "out of range is rejected":
    expect ValueError: discard eth_utils.parseGasAmount("4294967296")  # 2^32
    expect ValueError: discard eth_utils.parseGasAmount("0")
    expect ValueError: discard eth_utils.parseGasAmount("99999999999999999999999")  # uint64 overflow

  test "malformed input is rejected":
    expect ValueError: discard eth_utils.parseGasAmount("")
    expect ValueError: discard eth_utils.parseGasAmount("abc")
    expect ValueError: discard eth_utils.parseGasAmount("-1")
    expect ValueError: discard eth_utils.parseGasAmount("21000.5")
    expect ValueError: discard eth_utils.parseGasAmount(" 21000")
    expect ValueError: discard eth_utils.parseGasAmount("0x5208")

  test "serializes as an unquoted JSON integer":
    let node = %* {"gasAmount": eth_utils.parseGasAmount("3000000000")}
    check node["gasAmount"].kind == JInt
    check $node == """{"gasAmount":3000000000}"""
