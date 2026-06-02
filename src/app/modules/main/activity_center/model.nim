import app/modules/shared_models/model_utils
import nimqml, tables, json, sequtils, strutils
import ./item
import ../../../../app_service/service/activity_center/dto/notification

type
  NotifRoles {.pure.} = enum
    Id = UserRole + 1
    ChatId
    CommunityId
    MembershipStatus
    SectionId
    Name
    NewsTitle
    NewsDescription
    NewsContent
    NewsImageUrl
    NewsLink
    NewsLinkLabel
    NotificationType
    Message
    Timestamp
    PreviousTimestamp
    Read
    Dismissed
    Accepted
    Author
    RepliedMessage
    ChatType
    TokenData
    InstallationId

QtObject:
  type
    Model* = ref object of QAbstractListModel
      activityCenterNotifications*: seq[Item]

  proc setup(self: Model)
  proc delete(self: Model)
  proc newModel*(): Model =
    new(result, delete)
    result.activityCenterNotifications = @[]
    result.setup()

  proc getUnreadNotificationsForChat*(self: Model, chatId: string): seq[string] =
    result =  @[]
    for notification in self.activityCenterNotifications:
      if (notification.chatId == chatId and not notification.read):
        result.add(notification.id)

  proc markAllAsRead*(self: Model) =
    for activityCenterNotification in self.activityCenterNotifications:
      activityCenterNotification.read = true

    let topLeft = self.createIndex(0, 0, nil)
    let bottomRight = self.createIndex(self.activityCenterNotifications.len - 1, 0, nil)
    defer: topLeft.delete
    defer: bottomRight.delete
    self.dataChanged(topLeft, bottomRight, @[NotifRoles.Read.int])

  method rowCount*(self: Model, index: QModelIndex = nil): int = self.activityCenterNotifications.len

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.activityCenterNotifications.len, role, NotifRoles)

    let activityNotificationItem = self.activityCenterNotifications[index.row]
    let notificationItemRole = role.NotifRoles
    case notificationItemRole:
      of NotifRoles.Id: result = newQVariant(activityNotificationItem.id)
      of NotifRoles.ChatId: result = newQVariant(activityNotificationItem.chatId)
      of NotifRoles.CommunityId: result = newQVariant(activityNotificationItem.communityId)
      of NotifRoles.MembershipStatus: result = newQVariant(activityNotificationItem.membershipStatus.int)
      of NotifRoles.SectionId: result = newQVariant(activityNotificationItem.sectionId)
      of NotifRoles.Name: result = newQVariant(activityNotificationItem.name)
      of NotifRoles.NewsTitle: result = newQVariant(activityNotificationItem.newsTitle)
      of NotifRoles.NewsDescription: result = newQVariant(activityNotificationItem.newsDescription)
      of NotifRoles.NewsContent: result = newQVariant(activityNotificationItem.newsContent)
      of NotifRoles.NewsImageUrl: result = newQVariant(activityNotificationItem.newsImageUrl)
      of NotifRoles.NewsLink: result = newQVariant(activityNotificationItem.newsLink)
      of NotifRoles.NewsLinkLabel: result = newQVariant(activityNotificationItem.newsLinkLabel)
      of NotifRoles.Author: result = newQVariant(activityNotificationItem.author)
      of NotifRoles.NotificationType: result = newQVariant(activityNotificationItem.notificationType.int)
      of NotifRoles.Message: result = if not activityNotificationItem.messageItem.isNil:
                                        newQVariant(activityNotificationItem.messageItem)
                                      else:
                                        newQVariant()
      of NotifRoles.Timestamp: result = newQVariant(activityNotificationItem.timestamp)
      of NotifRoles.PreviousTimestamp: result = newQVariant(if index.row > 0:
                                                              self.activityCenterNotifications[index.row - 1].timestamp
                                                            else:
                                                              0)
      of NotifRoles.Read: result = newQVariant(activityNotificationItem.read.bool)
      of NotifRoles.Dismissed: result = newQVariant(activityNotificationItem.dismissed.bool)
      of NotifRoles.Accepted: result = newQVariant(activityNotificationItem.accepted.bool)
      of NotifRoles.RepliedMessage: result = if not activityNotificationItem.repliedMessageItem.isNil:
                                        newQVariant(activityNotificationItem.repliedMessageItem)
                                      else:
                                        newQVariant()
      of NotifRoles.ChatType: result = newQVariant(activityNotificationItem.chatType.int)
      of NotifRoles.TokenData: result = newQVariant(activityNotificationItem.tokenDataItem)
      of NotifRoles.InstallationId: result = newQVariant(activityNotificationItem.installationId)

  method roleNames(self: Model): Table[int, string] =
    {
      NotifRoles.Id.int:"id",
      NotifRoles.ChatId.int:"chatId",
      NotifRoles.CommunityId.int:"communityId",
      NotifRoles.MembershipStatus.int: "membershipStatus",
      NotifRoles.SectionId.int: "sectionId",
      NotifRoles.Name.int: "name",
      NotifRoles.NewsTitle.int: "newsTitle",
      NotifRoles.NewsDescription.int: "newsDescription",
      NotifRoles.NewsContent.int: "newsContent",
      NotifRoles.NewsImageUrl.int: "newsImageUrl",
      NotifRoles.NewsLink.int: "newsLink",
      NotifRoles.NewsLinkLabel.int: "newsLinkLabel",
      NotifRoles.Author.int: "author",
      NotifRoles.NotificationType.int: "notificationType",
      NotifRoles.Message.int: "message",
      NotifRoles.Timestamp.int: "timestamp",
      NotifRoles.PreviousTimestamp.int: "previousTimestamp",
      NotifRoles.Read.int: "read",
      NotifRoles.Dismissed.int: "dismissed",
      NotifRoles.Accepted.int: "accepted",
      NotifRoles.RepliedMessage.int: "repliedMessage",
      NotifRoles.ChatType.int: "chatType",
      NotifRoles.TokenData.int: "tokenData",
      NotifRoles.InstallationId.int: "installationId",
    }.toTable

  proc findNotificationIndex(self: Model, notificationId: string): int {.slot.} =
    if notificationId.len == 0:
      return -1
    for i in 0 ..< self.activityCenterNotifications.len:
      if self.activityCenterNotifications[i].id == notificationId:
        return i
    return -1

  proc markActivityCenterNotificationUnread*(self: Model, notificationId: string) =
    let i = self.findNotificationIndex(notificationId)
    if i == -1:
      return

    self.activityCenterNotifications[i].read = false
    let index = self.createIndex(i, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[NotifRoles.Read.int])

  proc markActivityCenterNotificationRead*(self: Model, notificationId: string) =
    let i = self.findNotificationIndex(notificationId)
    if i == -1:
      return

    self.activityCenterNotifications[i].read = true
    let index = self.createIndex(i, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[NotifRoles.Read.int])

  proc activityCenterNotificationAccepted*(self: Model, notificationId: string) =
    let i = self.findNotificationIndex(notificationId)
    if i == -1:
      return

    self.activityCenterNotifications[i].read = true
    self.activityCenterNotifications[i].accepted = true
    let index = self.createIndex(i, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[NotifRoles.Accepted.int, NotifRoles.Read.int])

  proc activityCenterNotificationDismissed*(self: Model, notificationId: string) =
    let i = self.findNotificationIndex(notificationId)
    if i == -1:
      return

    self.activityCenterNotifications[i].read = true
    self.activityCenterNotifications[i].dismissed = true
    let index = self.createIndex(i, 0, nil)
    defer: index.delete
    self.dataChanged(index, index, @[NotifRoles.Dismissed.int, NotifRoles.Read.int])

  proc updateCommunityMembershipStatus*(self: Model, communityId: string, memberPubkey: string, status: ActivityCenterMembershipStatus) =
    for i, notification in self.activityCenterNotifications:
      if notification.notificationType == ActivityCenterNotificationType.CommunityMembershipRequest and
          notification.communityId == communityId and
          (notification.author == memberPubkey or notification.chatId == memberPubkey):
        notification.membershipStatus = status
        let index = self.createIndex(i, 0, nil)
        defer: index.delete
        self.dataChanged(index, index, @[NotifRoles.MembershipStatus.int])

  proc removeNotifications*(self: Model, ids: seq[string]) =
    var i = 0
    var indexesToDelete: seq[int] = @[]
    for activityCenterNotification in self.activityCenterNotifications:
      for id in ids:
        if (activityCenterNotification.id == id):
          indexesToDelete.add(i)
          break
      i = i + 1

    i = 0
    for index in indexesToDelete:
      let indexUpdated = index - i
      let modelIndex = newQModelIndex()
      defer: modelIndex.delete
      self.beginRemoveRows(modelIndex, indexUpdated, indexUpdated)
      self.activityCenterNotifications.delete(indexUpdated)
      self.endRemoveRows()
      i = i + 1

  proc setNewData*(self: Model, activityCenterNotifications: seq[Item]) =
    self.beginResetModel()
    self.activityCenterNotifications = activityCenterNotifications
    self.endResetModel()

  proc updateActivityCenterNotification*(self: Model, ind: int, newNotification: Item) =
    if self.activityCenterNotifications[ind].notificationType == ActivityCenterNotificationType.CommunityMembershipRequest and
        self.activityCenterNotifications[ind].membershipStatus in [
          ActivityCenterMembershipStatus.Accepted,
          ActivityCenterMembershipStatus.Declined,
        ] and
        newNotification.membershipStatus notin [
          ActivityCenterMembershipStatus.Accepted,
          ActivityCenterMembershipStatus.Declined,
        ]:
      newNotification.membershipStatus = self.activityCenterNotifications[ind].membershipStatus

    self.activityCenterNotifications[ind] = newNotification
    let index = self.createIndex(ind, 0, nil)
    defer: index.delete
    self.dataChanged(index, index)

  proc upsertActivityCenterNotification*(self: Model, newNotification: Item) =
    for i, notification in self.activityCenterNotifications:
      if newNotification.id == notification.id:
        self.updateActivityCenterNotification(i, newNotification)
        return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    var indexToInsert = self.activityCenterNotifications.len
    for i, notification in self.activityCenterNotifications:
      if newNotification.timestamp > notification.timestamp:
        indexToInsert = i
        break

    self.beginInsertRows(parentModelIndex, indexToInsert, indexToInsert)
    self.activityCenterNotifications.insert(newNotification, indexToInsert)
    self.endInsertRows()

    let indexToUpdate = indexToInsert - 2
    if indexToUpdate >= 0 and indexToUpdate < self.activityCenterNotifications.len:
      let index = self.createIndex(indexToUpdate, 0, nil)
      defer: index.delete
      self.dataChanged(index, index, @[NotifRoles.PreviousTimestamp.int])

  proc upsertActivityCenterNotifications*(self: Model, activityCenterNotifications: seq[Item]) =
    if self.activityCenterNotifications.len == 0:
      self.setNewData(activityCenterNotifications)
    else:
      for activityCenterNotification in activityCenterNotifications:
        self.upsertActivityCenterNotification(activityCenterNotification)

  proc setup(self: Model) =
    self.QAbstractListModel.setup
  proc delete(self: Model) =
    self.QAbstractListModel.delete
