import unittest

import app/modules/main/chat_section/[model, Item]

import app_service/common/types

proc createTestChatItem(id: string, catId: string = "", isCategory: bool = false): ChatItem =
  discard
  return initChatItem(
      id = id,
      name = "",
      usesDefaultName = true,
      icon = "",
      color = "",
      emoji = "",
      description = "",
      `type` = if isCategory: CATEGORY_TYPE else: 0,
      memberRole = MemberRole.None,
      lastMessageTimestamp = 0,
      lastMessageText = "",
      hasUnreadMessages = false,
      notificationsCount = 0,
      muted = false,
      blocked = false,
      active = false,
      position = 0,
      categoryId = catId,
    )

let chatA = createTestChatItem("0xa")
let chatB = createTestChatItem("0xb")
let chatC = createTestChatItem("0xc", catId = "0xcatA")
let catA = createTestChatItem("0xcatA", catId = "0xcatA", isCategory = true)

suite "empty member model":
  let model = newModel()

  test "initial size":
    require(model.rowCount() == 0)

suite "updating chat items":
  setup:
    let model = newModel()
    model.setData(@[chatA, catA, chatB])
    check(model.rowCount() == 3)

  test "update can post values":
    # Call with the same values, so nothing should change
    var updatedRoles = model.changeCanPostValues(
        id = "0xa",
        canPost = true,
        canView = true,
        canPostReactions = true,
        viewersCanPostReactions = true,
      )
    check(updatedRoles.len() == 0)

    # Call with two updated value
    updatedRoles = model.changeCanPostValues(
        id = "0xa",
        canPost = false,
        canView = false,
        canPostReactions = true,
        viewersCanPostReactions = true,
      )
    # Four roles should be updated because there are collateral updates
    check(updatedRoles.len() == 4)

    let item = model.getItemById("0xa")
    check(item.canPost == false)
    check(item.canView == false)

  test "update item details by id":
    # Don't touch hideIfPermissionsNotMet
    var updatedRoles = model.updateCommunityItemDetailsById(
        id = "0xa",
        name = "Chat A",
        description = "Desc A",
        emoji = "emojiA",
        color = "#FF0000",
        hideIfPermissionsNotMet = false,
      )
    check(updatedRoles.len() == 4)

    # Only update hideIfPermissionsNotMet
    updatedRoles = model.updateCommunityItemDetailsById(
        id = "0xa",
        name = "Chat A",
        description = "Desc A",
        emoji = "emojiA",
        color = "#FF0000",
        hideIfPermissionsNotMet = true,
      )
    # Two roles because hideIfPermissionsNotMet has a collateral role update
    check(updatedRoles.len() == 2)

  test "append a chat to category and change the opened state":
    # Append a chat to a category
    model.appendItem(chatC)
    check(model.rowCount() == 4)

    # Check if the chat is now under the category
    let index = model.getItemIdxById("0xc")
    # Index is 2 because the category is at index 1 and the chat is appended after it
    check(index == 2)

    # Check that the category is opened at the start
    var cat = model.getItemById("0xcatA")
    check(cat.categoryOpened == true)

    # Change the category's opened state to false, it will affect the chat as well
    model.changeCategoryOpened("0xcatA", false)
    cat = model.getItemById("0xcatA")
    check(cat.categoryOpened == false)
    let chat = model.getItemById("0xc")
    check(chat.categoryOpened == false)

  test "parent timestamp updates thread sort timestamps":
    let parent = createTestChatItem("0xparent")
    let thread = initChatItem(
      id = "0xthread",
      name = "",
      usesDefaultName = true,
      icon = "",
      color = "",
      emoji = "",
      description = "",
      `type` = 0,
      memberRole = MemberRole.None,
      lastMessageTimestamp = 0,
      lastMessageText = "",
      hasUnreadMessages = false,
      notificationsCount = 0,
      muted = false,
      blocked = false,
      active = false,
      position = 0,
      isThread = true,
      parentChatId = parent.id,
    )
    model.setData(@[parent, thread])

    model.updateLastMessageOnItemById("0xparent", "new message", 123)

    check(parent.sortTimestamp == 123)
    check(thread.sortTimestamp == 123)

suite "hidden role (chat list virtualization)":
  setup:
    # fresh items per test — ChatItem is a ref, shared globals leak state
    let model = newModel()
    model.setData(@[createTestChatItem("0xa"),
                    createTestChatItem("0xcatA", catId = "0xcatA", isCategory = true)])
    model.appendItem(createTestChatItem("0xc", catId = "0xcatA"))
    check(model.rowCount() == 3)

  test "chat in a closed category is hidden, category and uncategorized chats are not":
    check(model.getItemById("0xc").hidden == false)

    model.changeCategoryOpened("0xcatA", false)
    check(model.getItemById("0xc").hidden == true)
    check(model.getItemById("0xcatA").hidden == false)
    check(model.getItemById("0xa").hidden == false)

    model.changeCategoryOpened("0xcatA", true)
    check(model.getItemById("0xc").hidden == false)

  test "active chat stays visible in a closed category":
    model.setActiveItem("0xc")
    model.changeCategoryOpened("0xcatA", false)
    check(model.getItemById("0xc").hidden == false)

    # deactivating it while the category is closed hides it again
    model.setActiveItem("0xa")
    check(model.getItemById("0xc").hidden == true)

  test "unread and notifications keep a closed-category chat visible, muted unread does not":
    model.changeCategoryOpened("0xcatA", false)

    model.updateNotificationsForItemById("0xc", hasUnreadMessages = true, notificationsCount = 0)
    check(model.getItemById("0xc").hidden == false)

    model.changeMutedOnItemById("0xc", muted = true)
    check(model.getItemById("0xc").hidden == true)

    model.updateNotificationsForItemById("0xc", hasUnreadMessages = true, notificationsCount = 1)
    check(model.getItemById("0xc").hidden == false)

    model.updateNotificationsForItemById("0xc", hasUnreadMessages = false, notificationsCount = 0)
    check(model.getItemById("0xc").hidden == true)
