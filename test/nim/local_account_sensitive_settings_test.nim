import unittest

import app/global/local_account_sensitive_settings

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
