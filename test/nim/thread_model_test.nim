import unittest, tables
import std/importutils
import nimqml
import app/modules/shared_models/[thread_model, message_item]
import app/modules/shared_models/thread_participant_model as participants
from seaqt/QtCore/gen_qabstractitemmodel import nil
from seaqt/QtCore/gen_qabstractitemmodel_types import nil

proc value[T](model: T, row: int, name: string): QVariant =
  let index = model.createIndex(row, 0, nil)
  defer: index.delete()
  for role, roleName in model.roleNames():
    if roleName == name:
      return model.data(index, role)

suite "chat info threads":
  test "contact changes refresh sender and participant snapshots without replacing child models":
    let model = thread_model.newModel()
    defer: model.delete()
    privateAccess(thread_model.Model)
    privateAccess(typeof(model.items[0]))
    model.upsert(ThreadSummary(threadId: "thread", lastMessageSenderId: "alice",
      lastMessageSenderName: "Alice", participants: @[
        Participant(id: "alice", name: "Alice"), Participant(id: "bob", name: "Bob")]))
    let child = model.items[0].participants
    model.updateContact("alice", "Alice updated", "avatar.png", 5)
    check(model.items[0].participants == child)
    let name = model.value(0, "lastMessageSenderName")
    let image = model.value(0, "lastMessageSenderImage")
    let participant = child.value(0, "name")
    let other = child.value(1, "name")
    check(name.stringVal == "Alice updated")
    check(image.stringVal == "avatar.png")
    check(participant.stringVal == "Alice updated")
    check(other.stringVal == "Bob")
    name.delete()
    image.delete()
    participant.delete()
    other.delete()

  test "explicit disposal releases participant rows and can be repeated safely":
    let model = thread_model.newModel()
    model.upsert(ThreadSummary(threadId: "thread", participants: @[Participant(id: "alice")]))
    model.delete()
    check(model.rowCount(nil) == 0)
    model.delete()

  test "lists threads independently of loaded parent messages and updates by identity":
    let model = thread_model.newModel()
    defer: model.delete()
    var summary = ThreadSummary(threadId: "thread-1", originalMessageId: "unloaded-parent",
      title: "Design", messagesCount: 2, notificationCount: 1,
      lastMessageTimestamp: 100, participantsCount: 1,
      participants: @[Participant(id: "alice", name: "Alice")])
    model.upsert(summary)
    check(model.rowCount(nil) == 1)
    let key = model.value(0, "key")
    check(key.stringVal == "thread-1")
    key.delete()

    summary.title = "Updated design"
    summary.notificationCount = 0
    summary.lastMessageTimestamp = 200
    summary.participants[0].name = "Alice updated"
    model.upsert(summary)
    check(model.rowCount(nil) == 1)
    let title = model.value(0, "title")
    check(title.stringVal == "Updated design")
    title.delete()
    let notifications = model.value(0, "notificationCount")
    check(notifications.intVal == 0)
    notifications.delete()
    let timestamp = model.value(0, "lastMessageTimestamp")
    check(timestamp.intVal == 200)
    timestamp.delete()

    model.upsert(ThreadSummary(threadId: "thread-2", title: "Roadmap"))
    check(model.rowCount(nil) == 2)
    model.retain(@["thread-2"])
    check(model.rowCount(nil) == 1)
    let remaining = model.value(0, "key")
    check(remaining.stringVal == "thread-2")
    remaining.delete()
    model.upsert(ThreadSummary(threadId: "thread-2", title: "Updated roadmap"))
    check(model.rowCount(nil) == 1)
    model.retain(@[])
    check(model.rowCount(nil) == 0)
    model.upsert(ThreadSummary())
    check(model.rowCount(nil) == 0)

  test "unread and activity updates notify only their roles without resetting rows":
    let model = thread_model.newModel()
    defer: model.delete()
    var summary = ThreadSummary(threadId: "thread", notificationCount: 2,
      lastMessageTimestamp: 100, participantsCount: 1,
      participants: @[Participant(id: "alice", name: "Alice")])
    model.upsert(summary)
    let qtModel = gen_qabstractitemmodel_types.QAbstractItemModel(h: model.vptr, owned: false)
    var changed: seq[seq[cint]]
    var resetCount = 0
    gen_qabstractitemmodel.onDataChanged(qtModel,
      proc(topLeft, bottomRight: gen_qabstractitemmodel_types.QModelIndex, roles: openArray[cint]) =
        changed.add(@roles))
    gen_qabstractitemmodel.onModelReset(qtModel, proc() = inc resetCount)
    var unreadRole, timestampRole: cint
    for role, name in model.roleNames():
      if name == "notificationCount": unreadRole = role.cint
      if name == "lastMessageTimestamp": timestampRole = role.cint
    summary.notificationCount = 0
    model.upsert(summary)
    check(changed == @[@[unreadRole]])
    model.upsert(summary)
    check(changed.len == 1)
    summary.participants = @[Participant(id: "alice", name: "Updated Alice")]
    model.upsert(summary)
    check(changed.len == 1)
    summary.lastMessageTimestamp = 200
    model.upsert(summary)
    check(changed == @[@[unreadRole], @[timestampRole]])
    check(resetCount == 0)

  test "deleted threads are removed from the info list without removing other threads":
    let model = thread_model.newModel()
    defer: model.delete()
    model.upsert(ThreadSummary(threadId: "deleted", title: "Deleted"))
    model.upsert(ThreadSummary(threadId: "keep", title: "Keep"))
    model.upsert(ThreadSummary(threadId: "deleted", deleted: true))
    check model.rowCount(nil) == 1
    let remaining = model.value(0, "key")
    check remaining.stringVal == "keep"
    remaining.delete()
