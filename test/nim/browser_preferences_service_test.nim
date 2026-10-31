import unittest

import app_service/service/browser_preferences/service as browser_preferences_service

suite "browser preferences service — validation":
  setup:
    let service = browser_preferences_service.newService()

  test "put rejects empty or whitespace category or key":
    check not service.put("", "tab-width", "1200")
    check not service.put("browser-tabs", "", "value")
    check not service.put("   ", "key", "value")
    check not service.put("browser-tabs", "\t", "value")

  test "get returns empty string for empty or whitespace category or key":
    check service.get("", "key") == ""
    check service.get("browser-tabs", "") == ""
    check service.get("  ", "key") == ""
    check service.get("browser-tabs", "  ") == ""

  test "purgeCategory rejects empty or whitespace category":
    check not service.purgeCategory("", @["a"])
    check not service.purgeCategory("   ", @["a"])
