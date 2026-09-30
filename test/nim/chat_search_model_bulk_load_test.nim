import unittest, tables

import nimqml

import app/modules/main/app_search/io_interface
import app/modules/main/app_search/models/[chat_search_item, chat_search_model]
import app/modules/shared/qt_model_spy

# Mirrors the app-search module: builds from whatever chats the chat service
# holds when asked. The model only asks once everything is loaded.
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
    membersCount = 0,
    onlineStatus = 0,
  )

suite "chat search model - single build once everything is loaded":
  setup:
    let spy = newQtModelSpy()
    spy.enable()
    let delegate = LoadingDelegate()
    delegate.chats = @[createTestItem("chat-a"), createTestItem("chat-b")]
    let model = chat_search_model.newModel(delegate)
    delegate.model = model

  teardown:
    spy.disable()

  test "rowCount before everything is loaded reports no rows and builds nothing":
    check(model.rowCount(nil) == 0)
    check(model.rowCount(nil) == 0)
    check(delegate.builds == 0)
    check(spy.countResets() == 0)

  test "everything loaded after an early rowCount builds once with a reset":
    check(model.rowCount(nil) == 0)
    spy.clear()
    model.onEverythingLoaded()
    check(delegate.builds == 1)
    check(spy.countResets() == 1)
    check(model.rowCount(nil) == 2)
    check(delegate.builds == 1)

  test "everything loaded before any rowCount defers the build to the first rowCount":
    model.onEverythingLoaded()
    check(delegate.builds == 0)
    check(model.rowCount(nil) == 2)
    check(delegate.builds == 1)
    check(spy.countResets() == 0)
    check(model.rowCount(nil) == 2)
    check(delegate.builds == 1)
