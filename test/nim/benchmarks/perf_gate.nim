# Wall-clock perf gates flake on loaded CI executors. BENCH_ASSERTS=0 (set by
# the CI target in makefiles/nim-tests.mk) downgrades them to report-only;
# structural gates (resets/row-churn/counts) stay hard doAsserts.
import std/[os, strutils]

proc perfAssertsEnabled*(): bool =
  getEnv("BENCH_ASSERTS", "1").toLowerAscii() notin ["0", "false", "off"]

template perfAssert*(cond: untyped, msg: string) =
  if perfAssertsEnabled():
    doAssert cond, msg
  elif not (cond):
    echo "PERF GATE SKIPPED (BENCH_ASSERTS=0): ", msg

# BENCH_QUICK=1 (set by the CI target) trims size sweeps to the assert-relevant
# sizes: gates that pin a size keep it, structural gates keep the smallest.
proc benchQuick*(): bool =
  getEnv("BENCH_QUICK", "0").toLowerAscii() in ["1", "true", "on"]

proc benchSizes*(full, quick: openArray[int]): seq[int] =
  if benchQuick(): @quick else: @full
