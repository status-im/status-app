import unittest, os
from std/tempfiles import createTempDir
import app/global/local_account_sensitive_settings
import constants

suite "Last section thread record":
  test "parses a selected thread record":
    let record = parseLastSectionThread(
      """{"threadId":"thread-1","parentChatId":"chat-1","presentation":"selectedChat"}""")

    check record.threadId == "thread-1"
    check record.parentChatId == "chat-1"
    check record.presentation == THREAD_PRESENTATION_SELECTED_CHAT

  test "parses a side panel thread record":
    let record = parseLastSectionThread(
      """{"threadId":"thread-1","parentChatId":"chat-1","presentation":"sidePanel"}""")

    check record.threadId == "thread-1"
    check record.parentChatId == "chat-1"
    check record.presentation == THREAD_PRESENTATION_SIDE_PANEL

  test "rejects incomplete and malformed records":
    for value in [
      "",
      """{"threadId":"thread-1","parentChatId":"chat-1"}""",
      """{"threadId":"","parentChatId":"chat-1","presentation":"sidePanel"}""",
      """{"threadId":"thread-1","parentChatId":"chat-1","presentation":"other"}""",
      "not-json",
    ]:
      let record = parseLastSectionThread(value)
      check record.threadId == ""
      check record.parentChatId == ""
      check record.presentation == ""

suite "LocalAccountSensitiveSettings detach":
  var settingsDir: string

  setup:
    settingsDir = createTempDir("sensitive_settings_detach_test_", "")

  teardown:
    removeDir(settingsDir)

  test "detach serves defaults until the next profile binds its own file":
    let settings = newLocalAccountSensitiveSettings(settingsDir)
    settings.setFileName("profile")
    settings.setExpandUsersList(false) # the default is true
    settings.detach()
    check settings.getExpandUsersList()

    settings.setFileName("other_profile")
    check settings.getExpandUsersList()

    settings.detach()
    settings.setFileName("profile")
    check not settings.getExpandUsersList()
