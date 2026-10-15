import nimqml, tables, sets, sequtils
import model_utils, message_item
import thread_participant_model as participants

type
  ModelRole {.pure.} = enum
    Key = UserRole + 1
    OriginalMessageId
    Title
    MessagesCount
    NotificationCount
    ParticipantsCount
    ParticipantsModel
    LastMessageSenderName
    LastMessageSenderImage
    LastMessageSenderColorId
    LastMessageText
    LastMessageTimestamp

  Row = object
    summary: ThreadSummary
    participants: participants.Model

QtObject:
  type Model* = ref object of QAbstractListModel
    items: seq[Row]
    indices: Table[string, int]

  proc delete*(self: Model)

  proc newModel*(): Model =
    new(result, delete)
    result.QAbstractListModel.setup()

  method rowCount(self: Model, index: QModelIndex = nil): int =
    self.items.len

  method roleNames(self: Model): Table[int, string] =
    {
      ModelRole.Key.int: "key",
      ModelRole.OriginalMessageId.int: "originalMessageId",
      ModelRole.Title.int: "title",
      ModelRole.MessagesCount.int: "messagesCount",
      ModelRole.NotificationCount.int: "notificationCount",
      ModelRole.ParticipantsCount.int: "participantsCount",
      ModelRole.ParticipantsModel.int: "participantsModel",
      ModelRole.LastMessageSenderName.int: "lastMessageSenderName",
      ModelRole.LastMessageSenderImage.int: "lastMessageSenderImage",
      ModelRole.LastMessageSenderColorId.int: "lastMessageSenderColorId",
      ModelRole.LastMessageText.int: "lastMessageText",
      ModelRole.LastMessageTimestamp.int: "lastMessageTimestamp",
    }.toTable

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)
    let row = self.items[index.row]
    case role.ModelRole
    of ModelRole.Key: result = newQVariant(row.summary.threadId)
    of ModelRole.OriginalMessageId: result = newQVariant(row.summary.originalMessageId)
    of ModelRole.Title: result = newQVariant(row.summary.title)
    of ModelRole.MessagesCount: result = newQVariant(row.summary.messagesCount)
    of ModelRole.NotificationCount: result = newQVariant(row.summary.notificationCount)
    of ModelRole.ParticipantsCount: result = newQVariant(row.summary.participantsCount)
    of ModelRole.ParticipantsModel: result = newQVariant(row.participants)
    of ModelRole.LastMessageSenderName: result = newQVariant(row.summary.lastMessageSenderName)
    of ModelRole.LastMessageSenderImage: result = newQVariant(row.summary.lastMessageSenderImage)
    of ModelRole.LastMessageSenderColorId: result = newQVariant(row.summary.lastMessageSenderColorId)
    of ModelRole.LastMessageText: result = newQVariant(row.summary.lastMessageText)
    of ModelRole.LastMessageTimestamp: result = newQVariant(row.summary.lastMessageTimestamp)
    else: result = newQVariant()

  proc upsert*(self: Model, summary: ThreadSummary) =
    if summary.threadId.len == 0:
      return
    let i = self.indices.getOrDefault(summary.threadId, -1)
    if i >= 0:
      if self.items[i].summary == summary:
        return
      let ind = i
      updateRolesAndNotify:
        let previous = self.items[ind].summary
        self.items[ind].summary = summary
        # Participant changes notify through the existing child model.
        self.items[ind].participants.setParticipants(summary.participants)
        addChangedRole(roles, previous.originalMessageId, summary.originalMessageId, ModelRole.OriginalMessageId.int): discard
        addChangedRole(roles, previous.title, summary.title, ModelRole.Title.int): discard
        addChangedRole(roles, previous.messagesCount, summary.messagesCount, ModelRole.MessagesCount.int): discard
        addChangedRole(roles, previous.notificationCount, summary.notificationCount, ModelRole.NotificationCount.int): discard
        addChangedRole(roles, previous.participantsCount, summary.participantsCount, ModelRole.ParticipantsCount.int): discard
        addChangedRole(roles, previous.lastMessageSenderName, summary.lastMessageSenderName, ModelRole.LastMessageSenderName.int): discard
        addChangedRole(roles, previous.lastMessageSenderImage, summary.lastMessageSenderImage, ModelRole.LastMessageSenderImage.int): discard
        addChangedRole(roles, previous.lastMessageSenderColorId, summary.lastMessageSenderColorId, ModelRole.LastMessageSenderColorId.int): discard
        addChangedRole(roles, previous.lastMessageText, summary.lastMessageText, ModelRole.LastMessageText.int): discard
        addChangedRole(roles, previous.lastMessageTimestamp, summary.lastMessageTimestamp, ModelRole.LastMessageTimestamp.int): discard
      return
    let parent = newQModelIndex()
    defer: parent.delete()
    self.beginInsertRows(parent, self.items.len, self.items.len)
    self.indices[summary.threadId] = self.items.len
    self.items.add(Row(summary: summary, participants: participants.newModel(summary.participants)))
    self.endInsertRows()

  proc updateContact*(self: Model, contactId, name, image: string, colorId: int) =
    if contactId.len == 0:
      return
    for row in self.items:
      if row.summary.lastMessageSenderId != contactId and
          not row.summary.participants.anyIt(it.id == contactId):
        continue
      var summary = row.summary
      summary.participants = row.summary.participants.mapIt(
        if it.id == contactId: participants.Participant(id: it.id, name: name, image: image, colorId: colorId)
        else: it)
      if summary.lastMessageSenderId == contactId:
        summary.lastMessageSenderName = name
        summary.lastMessageSenderImage = image
        summary.lastMessageSenderColorId = colorId
      self.upsert(summary)

  proc retain*(self: Model, threadIds: seq[string]) =
    let retained = threadIds.toHashSet()
    let parent = newQModelIndex()
    defer: parent.delete()
    var last = self.items.high
    var changed = false
    while last >= 0:
      if self.items[last].summary.threadId in retained:
        dec last
        continue
      var first = last
      while first > 0 and self.items[first - 1].summary.threadId notin retained:
        dec first
      self.beginRemoveRows(parent, first, last)
      let removed = self.items[first .. last]
      self.items.delete(first .. last)
      self.endRemoveRows()
      for row in removed:
        row.participants.delete()
      changed = true
      last = first - 1
    if not changed:
      return
    self.indices.clear()
    for i, row in self.items:
      self.indices[row.summary.threadId] = i

  proc delete*(self: Model) =
    for row in self.items:
      row.participants.delete()
    self.items.setLen(0)
    self.indices.clear()
    self.QAbstractListModel.delete()

