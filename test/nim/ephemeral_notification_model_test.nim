import sequtils, unittest

import app/core/notifications/details
import app/modules/main/[ephemeral_notification_item, ephemeral_notification_model]

proc addToast(model: Model, id: int64) =
  model.addItem(initItem(id, "Toast " & $id, details = NotificationDetails()))

suite "ephemeral notification model":
  test "portrait keeps the newest two toasts":
    let model = newModel()
    model.setMaxItems(2)
    for id in 1'i64 .. 5'i64:
      model.addToast(id)

    check model.items.mapIt(it.id) == @[4'i64, 5'i64]

  test "landscape keeps the newest three toasts":
    let model = newModel()
    model.setMaxItems(3)
    for id in 1'i64 .. 5'i64:
      model.addToast(id)

    check model.items.mapIt(it.id) == @[3'i64, 4'i64, 5'i64]

  test "rotating and dismissing toasts never restores evicted rows":
    let model = newModel()
    for id in 1'i64 .. 3'i64:
      model.addToast(id)

    model.setMaxItems(2)
    check model.items.mapIt(it.id) == @[2'i64, 3'i64]
    check model.getItemWithId(1).id == 0

    model.setMaxItems(3)
    model.removeItemWithId(1) # An already-evicted toast may finish closing.
    check model.items.mapIt(it.id) == @[2'i64, 3'i64]

    model.removeItemWithId(3)
    check model.items.mapIt(it.id) == @[2'i64]

    model.addToast(4)
    model.addToast(5)
    check model.items.mapIt(it.id) == @[2'i64, 4'i64, 5'i64]
