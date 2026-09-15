## Unit tests for the per-public-key memo backing `Utils.getColorId` /
## `Utils.getEmojiHashAsJson`. Pure Nim — no Qt, no status-go: the memo is the
## seam, and a counting `compute` closure stands in for the FFI round-trips.

import std/[options, strutils]
import unittest

import app/global/utils/pubkey_memo

suite "PubkeyMemo":

  test "repeated lookups of the same key compute once":
    let memo = newPubkeyMemo[int]()
    var calls = 0
    let compute = proc(pk: string): int =
      calls.inc
      pk.len

    check memo.get("0x04aa", compute) == 6
    check calls == 1
    for _ in 0 ..< 20:
      check memo.get("0x04aa", compute) == 6
    check calls == 1

  test "distinct keys miss and are kept side by side":
    let memo = newPubkeyMemo[int]()
    var calls = 0
    let compute = proc(pk: string): int =
      calls.inc
      pk.len

    check memo.get("zQ3sh", compute) == 5
    check memo.get("0x04aa", compute) == 6
    check calls == 2
    check memo.len == 2
    # both still served from the cache, and not swapped
    check memo.get("zQ3sh", compute) == 5
    check memo.get("0x04aa", compute) == 6
    check calls == 2

  test "memoized results are identical to the uncached ones":
    let memo = newPubkeyMemo[string]()
    let derive = proc(pk: string): string = pk.toUpperAscii & ":" & $pk.len
    let compute = proc(pk: string): string = derive(pk)

    for key in ["", "0x04aa", "zQ3shWQXBHRFmpTvUnKPUZ", "0X04AA"]:
      check memo.get(key, compute) == derive(key)
      check memo.get(key, compute) == derive(key)

  test "the empty key is a normal cache entry, not a miss every time":
    let memo = newPubkeyMemo[int]()
    var calls = 0
    let compute = proc(pk: string): int =
      calls.inc
      -1

    check memo.get("", compute) == -1
    check memo.get("", compute) == -1
    check calls == 1

  test "a falsy computed value is still cached":
    let memo = newPubkeyMemo[int]()
    var calls = 0
    let compute = proc(pk: string): int =
      calls.inc
      0

    check memo.get("0x04aa", compute) == 0
    check memo.get("0x04aa", compute) == 0
    check calls == 1

  test "peek reports hits without computing, clear empties the memo":
    let memo = newPubkeyMemo[int]()
    var calls = 0
    let compute = proc(pk: string): int =
      calls.inc
      7

    check memo.peek("0x04aa").isNone
    check calls == 0
    discard memo.get("0x04aa", compute)
    check memo.peek("0x04aa") == some(7)
    check calls == 1

    memo.clear()
    check memo.len == 0
    check memo.peek("0x04aa").isNone
    discard memo.get("0x04aa", compute)
    check calls == 2
