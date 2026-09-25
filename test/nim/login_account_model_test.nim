import unittest

import app/modules/onboarding/models/login_account_model as login_acc_model
import app/modules/onboarding/models/login_account_item as login_acc_item

proc makeItem(keyUid, name: string, order = 1): login_acc_item.Item =
  login_acc_item.initItem(
    order = order,
    name = name,
    icon = "",
    thumbnailImage = "",
    largeImage = "",
    keyUid = keyUid,
    colorId = 1,
    keycardPairing = "",
  )

suite "login account model removeItem":
  test "remove known keyUid drops the row":
    let model = login_acc_model.newModel()
    model.setItems(@[makeItem("uid_1", "Alice", 1), makeItem("uid_2", "Bob", 2)])
    check model.getCount() == 2

    model.removeItem("uid_1")

    check model.getCount() == 1
    check model.findIndexByKeyUid("uid_1") == -1
    check model.findIndexByKeyUid("uid_2") == 0

  test "remove unknown keyUid is a no-op":
    let model = login_acc_model.newModel()
    model.setItems(@[makeItem("uid_1", "Alice"), makeItem("uid_2", "Bob")])

    model.removeItem("missing")

    check model.getCount() == 2
    check model.findIndexByKeyUid("uid_1") == 0
    check model.findIndexByKeyUid("uid_2") == 1

  test "remove last item leaves an empty model":
    let model = login_acc_model.newModel()
    model.setItems(@[makeItem("uid_only", "Alice")])
    check model.getCount() == 1

    model.removeItem("uid_only")

    check model.getCount() == 0
    check model.findIndexByKeyUid("uid_only") == -1
