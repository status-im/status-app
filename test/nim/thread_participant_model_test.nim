import unittest, tables
import nimqml
import app/modules/shared_models/thread_participant_model
from seaqt/QtCore/gen_qabstractitemmodel import nil
from seaqt/QtCore/gen_qabstractitemmodel_types import nil

proc stringRole(model: Model, row: int, name: string): string =
  let index = model.createIndex(row, 0, nil)
  defer: index.delete
  for role, roleName in model.roleNames():
    if roleName == name:
      let value = model.data(index, role)
      defer: value.delete
      return value.stringVal

suite "thread participant model":
  test "updates, reorders, inserts and removes participants without resetting":
    let model = newModel(@[
      Participant(id: "alice", name: "Alice"),
      Participant(id: "bob", name: "Bob"),
      Participant(id: "carol", name: "Carol"),
    ])
    let qtModel = gen_qabstractitemmodel_types.QAbstractItemModel(h: model.vptr, owned: false)
    var resetCount = 0
    var changedRoles: seq[seq[cint]]
    gen_qabstractitemmodel.onModelReset(qtModel, proc() = inc resetCount)
    gen_qabstractitemmodel.onDataChanged(qtModel,
      proc(topLeft, bottomRight: gen_qabstractitemmodel_types.QModelIndex, roles: openArray[cint]) =
        changedRoles.add(@roles))

    let participants = @[
      Participant(id: "carol", name: "Carol updated"),
      Participant(id: "alice", name: "Alice"),
      Participant(id: "dave", name: "Dave"),
    ]
    model.setParticipants(participants)

    check(resetCount == 0)
    check(model.count() == 3)
    check(model.stringRole(0, "id") == "carol")
    check(model.stringRole(0, "name") == "Carol updated")
    check(model.stringRole(1, "id") == "alice")
    check(model.stringRole(2, "id") == "dave")
    require(changedRoles.len == 1)
    var nameRole = -1
    for role, name in model.roleNames():
      if name == "name":
        nameRole = role
    require(nameRole != -1)
    check(changedRoles[0] == @[nameRole.cint])

    model.setParticipants(participants)
    check(changedRoles.len == 1)
    check(resetCount == 0)

    model.setParticipants(@[])
    check(model.count() == 0)
    check(resetCount == 0)

    model.setParticipants(@[Participant(id: "bob", name: "Bob")])
    check(model.count() == 1)
    check(model.stringRole(0, "id") == "bob")
    check(resetCount == 0)
