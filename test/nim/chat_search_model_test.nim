import unittest, tables

import nimqml

import app/modules/main/app_search/io_interface
import app/modules/main/app_search/models/[chat_search_item, chat_search_model]

# Overridden because the base method raises; the model requests a lazy build
# on first rowCount, but these tests populate items via setItems directly.
type
  StubDelegate = ref object of io_interface.AccessInterface

method buildChatSearchModel(self: StubDelegate) =
  discard

proc createTestItem(chatId: string, lastMessageTimestamp: int,
    lastOwnMessageTimestamp: int, canPost: bool = true): ChatSearchItem =
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
    lastMessageTimestamp = lastMessageTimestamp,
    lastOwnMessageTimestamp = lastOwnMessageTimestamp,
    canPost = canPost,
  )

proc roleForName(model: chat_search_model.Model, name: string): int =
  for role, roleName in model.roleNames().pairs:
    if roleName == name:
      return role
  return -1

proc intData(model: chat_search_model.Model, row: int, roleName: string): int =
  let idx = model.createIndex(row, 0, nil)
  return model.data(idx, roleForName(model, roleName)).intVal

suite "chat search model - own message recency role":
  setup:
    let delegate = StubDelegate()
    let model = chat_search_model.newModel(delegate)
    model.setItems(@[
      createTestItem("chat-a", lastMessageTimestamp = 400, lastOwnMessageTimestamp = 400),
      createTestItem("chat-b", lastMessageTimestamp = 900, lastOwnMessageTimestamp = 100),
      createTestItem("channel-c", lastMessageTimestamp = 1000, lastOwnMessageTimestamp = 0),
    ])
    check(model.rowCount() == 3)

  test "exposes the lastOwnMessageTimestamp role":
    check(roleForName(model, "lastOwnMessageTimestamp") != -1)

  test "item data reports the own-send timestamp independently from any-message recency":
    check(intData(model, 0, "lastMessageTimestamp") == 400)
    check(intData(model, 0, "lastOwnMessageTimestamp") == 400)
    check(intData(model, 1, "lastOwnMessageTimestamp") == 100)
    check(intData(model, 2, "lastOwnMessageTimestamp") == 0)

  test "updateLastOwnMessageTimestampOnChatItem bumps only the target chat":
    model.updateLastOwnMessageTimestampOnChatItem("chat-b", 2000)
    check(intData(model, 1, "lastOwnMessageTimestamp") == 2000)
    check(intData(model, 0, "lastOwnMessageTimestamp") == 400)
    check(intData(model, 2, "lastOwnMessageTimestamp") == 0)

  test "updating an unknown chat is a no-op":
    model.updateLastOwnMessageTimestampOnChatItem("missing", 2000)
    check(intData(model, 0, "lastOwnMessageTimestamp") == 400)
    check(intData(model, 1, "lastOwnMessageTimestamp") == 100)
    check(intData(model, 2, "lastOwnMessageTimestamp") == 0)
