import unittest

import app/core/signals/signal_type_scan

suite "signal_type_scan - cheap type extraction":

  test "extracts the envelope type ahead of a nested event type":
    let raw = """{"type":"messages.new","event":{"type":"nested-should-be-ignored"}}"""
    check extractSignalType(raw) == "messages.new"

  test "extracts a dotted/dashed type value verbatim":
    check extractSignalType("""{"type":"wallet.token-lists.updated","event":{}}""") ==
      "wallet.token-lists.updated"

  test "handles a leading injected member before type (wtSeq instrumentation)":
    check extractSignalType("""{"wtSeq":42,"type":"wallet","event":{}}""") == "wallet"

  test "missing type member yields empty string":
    check extractSignalType("""{"event":{"foo":1}}""") == ""

  test "unterminated type value yields empty string":
    check extractSignalType("""{"type":"broken""") == ""

suite "signal_type_scan - known-type recognition":

  test "recognises handled signal types":
    check isKnownSignalType("messages.new")
    check isKnownSignalType("wallet.token-lists.updated")
    check isKnownSignalType("node.login")

  test "rejects unknown / unhandled types":
    check not isKnownSignalType("local-notifications")
    check not isKnownSignalType("some.type.nobody.handles")

  test "rejects empty type":
    check not isKnownSignalType("")

  test "an unknown type with a malformed body is rejected without parsing":
    # The manager relies on this: the decision is made from the type alone, so a
    # malformed body of an unhandled type never reaches parseJson.
    let raw = """{"type":"local-notifications","event":{ this is not : valid json ,,, }}"""
    check not isKnownSignalType(extractSignalType(raw))

suite "signal_type_scan - unhandled counter":

  test "counter accumulates and resets":
    resetUnhandledSignalCount()
    check unhandledSignalCount() == 0
    noteUnhandledSignal()
    noteUnhandledSignal()
    check unhandledSignalCount() == 2
    resetUnhandledSignalCount()
    check unhandledSignalCount() == 0
