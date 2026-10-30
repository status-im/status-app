import unittest

import ../../src/app/modules/main/chat_section/pending_navigation

suite "navigation during the first channel build":
  test "requested channel wins over the saved channel and list order":
    var pending = ChatNavigation(chatId: "privacy-news")
    let navigation = pending.resolveInitialNavigation(
      ["general", "saved", "privacy-news"], "saved")
    check navigation.chatId == "privacy-news"
    check pending.chatId == ""

  test "message target survives until the channel is selected":
    var pending = ChatNavigation(chatId: "privacy-news", messageId: "message")
    let navigation = pending.resolveInitialNavigation(["privacy-news"], "")
    check navigation.chatId == "privacy-news"
    check navigation.messageId == "message"
    check pending.messageId == ""

  test "newer navigation replaces both channel and message":
    var pending = ChatNavigation(chatId: "general", messageId: "old-message")
    pending = ChatNavigation(chatId: "privacy-news", messageId: "new-message")
    let navigation = pending.resolveInitialNavigation(["general", "privacy-news"], "general")
    check navigation.chatId == "privacy-news"
    check navigation.messageId == "new-message"

  test "cancelled navigation does not replay on a later visit":
    var pending = ChatNavigation(chatId: "privacy-news", messageId: "message")
    pending.clear()
    let navigation = pending.resolveInitialNavigation(["general", "privacy-news"], "general")
    check navigation.chatId == "general"
    check navigation.messageId == ""

  test "missing target falls back without scrolling to its message":
    var pending = ChatNavigation(chatId: "deleted", messageId: "message")
    let navigation = pending.resolveInitialNavigation(["general", "saved"], "saved")
    check navigation.chatId == "saved"
    check navigation.messageId == ""
    check pending.chatId == ""

  test "missing target and stale saved channel fall back to the first channel":
    var pending = ChatNavigation(chatId: "deleted")
    let navigation = pending.resolveInitialNavigation(["general", "privacy-news"], "also-deleted")
    check navigation.chatId == "general"

  test "empty community consumes the request without selecting a channel":
    var pending = ChatNavigation(chatId: "deleted", messageId: "message")
    let navigation = pending.resolveInitialNavigation([], "saved")
    check navigation.chatId == ""
    check navigation.messageId == ""
    check pending.chatId == ""

  test "consumed request cannot override a subsequent selection":
    var pending = ChatNavigation(chatId: "privacy-news")
    discard pending.resolveInitialNavigation(["general", "privacy-news"], "general")
    let navigation = pending.resolveInitialNavigation(["general", "privacy-news"], "general")
    check navigation.chatId == "general"
