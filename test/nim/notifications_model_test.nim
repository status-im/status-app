import unittest

import app_service/service/settings/dto/settings
import app/modules/main/profile_section/notifications/[model, item]

proc createNotificationItem(
    id: string,
    name: string = "Name",
    image: string = "image",
    color: string = "#ffffff",
    joinedTimestamp: int64 = 1,
    itemType: Type = Type.Community,
    muteAllMessages: bool = false,
    personalMentions: string = VALUE_NOTIF_SEND_ALERTS,
    globalMentions: string = VALUE_NOTIF_SEND_ALERTS,
    otherMessages: string = VALUE_NOTIF_TURN_OFF,
  ): Item =
  return initItem(
    id = id,
    name = name,
    image = image,
    color = color,
    joinedTimestamp = joinedTimestamp,
    itemType = itemType,
    muteAllMessages = muteAllMessages,
    personalMentions = personalMentions,
    globalMentions = globalMentions,
    otherMessages = otherMessages,
  )

suite "notifications model":
  test "add and remove items by id":
    let model = newModel()

    model.addItem(createNotificationItem("community-a"))
    model.addItem(createNotificationItem("community-b"))

    check(model.rowCount() == 2)
    check(model.findIndexForItemId("community-a") == 0)
    check(model.findIndexForItemId("community-b") == 1)

    model.removeItemById("community-a")

    check(model.rowCount() == 1)
    check(model.findIndexForItemId("community-a") == -1)
    check(model.findIndexForItemId("community-b") == 0)

  test "set items ignores empty replacement":
    let model = newModel()
    model.setItems(@[createNotificationItem("community-a")])

    model.setItems(@[])

    check(model.rowCount() == 1)
    check(model.items[0].id == "community-a")

  test "update name changes only matching item":
    let model = newModel()
    model.setItems(@[
      createNotificationItem("community-a", name = "Old name"),
      createNotificationItem("community-b", name = "Other name"),
    ])

    model.updateName("community-a", "New name")

    check(model.items[0].name == "New name")
    check(model.items[1].name == "Other name")

  test "update item changes presentation fields":
    let model = newModel()
    model.setItems(@[createNotificationItem("community-a", name = "Old", image = "old-image", color = "old-color")])

    model.updateItem("community-a", name = "New", image = "new-image", color = "new-color")

    check(model.items[0].name == "New")
    check(model.items[0].image == "new-image")
    check(model.items[0].color == "new-color")

  test "update exemptions updates notification settings and customized state":
    let model = newModel()
    model.setItems(@[createNotificationItem("community-a")])

    check(model.items[0].customized == false)

    model.updateExemptions(
      id = "community-a",
      muteAllMessages = true,
      personalMentions = VALUE_NOTIF_TURN_OFF,
      globalMentions = VALUE_NOTIF_SEND_ALERTS,
      otherMessages = VALUE_NOTIF_SEND_ALERTS,
    )

    check(model.items[0].muteAllMessages == true)
    check(model.items[0].personalMentions == VALUE_NOTIF_TURN_OFF)
    check(model.items[0].globalMentions == VALUE_NOTIF_SEND_ALERTS)
    check(model.items[0].otherMessages == VALUE_NOTIF_SEND_ALERTS)
    check(model.items[0].customized == true)

    model.updateExemptions("community-a")

    check(model.items[0].muteAllMessages == false)
    check(model.items[0].personalMentions == VALUE_NOTIF_SEND_ALERTS)
    check(model.items[0].globalMentions == VALUE_NOTIF_SEND_ALERTS)
    check(model.items[0].otherMessages == VALUE_NOTIF_TURN_OFF)
    check(model.items[0].customized == false)