import unittest, tables

import nimqml

import app/modules/main/app_search/io_interface
import app/modules/main/app_search/models/[chat_search_item, chat_search_model]
import app/modules/shared/qt_model_spy

# Mirrors the app-search module: builds from whatever chats the chat service
# holds right now, which is nothing until the async bulk load lands.
type
  LoadingDelegate = ref object of io_interface.AccessInterface
    model: chat_search_model.Model
    chats: seq[ChatSearchItem]
    builds: int

method buildChatSearchModel(self: LoadingDelegate) =
  inc self.builds
  self.model.setItems(self.chats)

proc createTestItem(chatId: string): ChatSearchItem =
  return chat_search_item.initItem(
    chatId,
    name = "name-" & chatId,
    color = "",
    colorId = 0,
    icon = "",
    sectionId = "section",
    sectionName = "Section",
    emoji = "",
    chatType = 1,
    lastMessageText = "",
    lastMessageTimestamp = 1,
    lastOwnMessageTimestamp = 1,
    canPost = true,
  )

suite "chat search model - bulk chat load after an early first rowCount":
  setup:
    let spy = newQtModelSpy()
    spy.enable()
    let delegate = LoadingDelegate()
    let model = chat_search_model.newModel(delegate)
    delegate.model = model

  teardown:
    spy.disable()

  test "chats arriving after the first rowCount repopulate the model with a reset":
    check(model.rowCount(nil) == 0)
    delegate.chats = @[createTestItem("chat-a"), createTestItem("chat-b")]
    spy.clear()
    # What the app-search controller does on SIGNAL_ACTIVE_CHATS_LOADED.
    delegate.buildChatSearchModel()
    check(model.rowCount(nil) == 2)
    check(spy.countResets() == 1)

  test "a bulk build before any rowCount needs no reset and is not rebuilt":
    delegate.chats = @[createTestItem("chat-a")]
    delegate.buildChatSearchModel()
    check(spy.countResets() == 0)
    check(model.rowCount(nil) == 1)
    check(delegate.builds == 1)
