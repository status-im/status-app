import unittest, tables, sets, sequtils

import nimqml
import seaqt/[qsortfilterproxymodel, qabstractitemmodel, qvariant]

import app/modules/main/app_search/io_interface
import app/modules/main/app_search/models/[chat_search_item, chat_search_model]

type
  ServiceDelegate = ref object of io_interface.AccessInterface
    model: chat_search_model.Model
    chats: seq[ChatSearchItem]
    builds: int

method buildChatSearchModel(self: ServiceDelegate) =
  inc self.builds
  self.model.setItems(self.chats)

proc createTestItem(chatId, name: string): ChatSearchItem =
  return chat_search_item.initItem(
    chatId,
    name = name,
    color = "",
    colorId = 0,
    icon = "",
    sectionId = "section",
    sectionName = "Section",
    emoji = "",
    chatType = 1,
    lastMessageUnparsedText = "",
    lastMessageTimestamp = 1,
    lastOwnMessageTimestamp = 1,
    canPost = true,
    membersCount = 0,
    onlineStatus = 0,
  )

proc roleForName(model: chat_search_model.Model, name: string): int =
  for role, roleName in model.roleNames().pairs:
    if roleName == name:
      return role
  return -1

proc proxyStrings(proxy: QSortFilterProxyModel, role: int): seq[string] =
  let root = gen_qabstractitemmodel_types.QModelIndex.create()
  for row in 0 ..< proxy.rowCount(root).int:
    result.add(proxy.data(proxy.index(row.cint, 0, root), role.cint).toString())

suite "chat search model - chat added while a proxy is attached before the build":
  setup:
    let delegate = ServiceDelegate()
    delegate.chats = @[
      createTestItem("chat-a", "Alice"),
      createTestItem("chat-x", "Cautious Familiar Gar"),
    ]
    let model = chat_search_model.newModel(delegate)
    delegate.model = model
    model.onEverythingLoaded()

    let proxy = QSortFilterProxyModel.create()
    proxy.setSourceModel(gen_qabstractitemmodel_types.QAbstractItemModel(h: model.vptr, owned: false))

    let chatIdRole = roleForName(model, "chatId")
    let nameRole = roleForName(model, "name")

  test "the added chat appears once in the proxy":
    model.addItem(createTestItem("chat-x", "Cautious Familiar Gar"))
    let ids = proxyStrings(proxy, chatIdRole)
    check(ids.len == 2)
    check(ids.toHashSet().len == ids.len)

  test "a rename after the add leaves no row with the old name":
    model.addItem(createTestItem("chat-x", "Cautious Familiar Gar"))
    discard proxyStrings(proxy, nameRole)
    model.updateChatItem("chat-x", "share-qa-partner", "", "", "")
    let names = proxyStrings(proxy, nameRole)
    check("Cautious Familiar Gar" notin names)
    check(names.count("share-qa-partner") == 1)

  test "a chat added before the build is picked up by the build":
    delegate.chats.add(createTestItem("chat-new", "New"))
    model.addItem(createTestItem("chat-new", "New"))
    let ids = proxyStrings(proxy, chatIdRole)
    check(ids.len == 3)
    check(ids.toHashSet().len == ids.len)
    check(delegate.builds == 1)
