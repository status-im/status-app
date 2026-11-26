import unittest

import app_service/service/privacy/operation_result

suite "privacy operation result":

  test "an empty backend error is a success":
    let r = operationResult("""{"error": "", "result": {"error": ""}}""")
    check r.success
    check r.errorMsg == ""

  test "a backend error is reported":
    let r = operationResult("""{"error": "", "result": {"error": "not zero-onboarded"}}""")
    check not r.success
    check r.errorMsg == "not zero-onboarded"

  test "an error raised in the task is reported":
    let r = operationResult("""{"error": "rpc failed", "result": ""}""")
    check not r.success
    check r.errorMsg == "rpc failed"

  test "a reply without a backend error field is not a success":
    let r = operationResult("""{"error": "", "result": {}}""")
    check not r.success

  test "malformed reply":
    let r = operationResult("not json")
    check not r.success
    check r.errorMsg != ""
