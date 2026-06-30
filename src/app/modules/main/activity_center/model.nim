import app/modules/shared_models/model_utils
import nimqml, tables, json, sequtils, strutils
import ./item
import ../../../../app_service/service/activity_center/dto/notification

type
  ModelRole {.pure.} = enum
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
      items*: seq[Item]

  proc setup(self: Model)
  proc delete(self: Model)
  proc newModel*(): Model =
    new(result, delete)
    result.items = @[]
    result.setup()

  proc getUnreadNotificationsForChat*(self: Model, chatId: string): seq[string] =
    result =  @[]
    for notification in self.items:
      if (notification.chatId == chatId and not notification.read):
        result.add(notification.id)

  proc markAllAsRead*(self: Model) =
    for activityCenterNotification in self.items:
      activityCenterNotification.read = true

    if self.items.len > 0:
      notifyRangeRolesChanged(0, self.items.len - 1, @[ModelRole.Read.int])

  method rowCount*(self: Model, index: QModelIndex = nil): int = self.items.len

  method data(self: Model, index: QModelIndex, role: int): QVariant =
    guardModelData(index, self.items.len, role, ModelRole)

    let activityNotificationItem = self.items[index.row]
    let notificationItemRole = role.ModelRole
    case notificationItemRole:
      of ModelRole.Id: result = newQVariant(activityNotificationItem.id)
      of ModelRole.ChatId: result = newQVariant(activityNotificationItem.chatId)
      of ModelRole.CommunityId: result = newQVariant(activityNotificationItem.communityId)
      of ModelRole.MembershipStatus: result = newQVariant(activityNotificationItem.membershipStatus.int)
      of ModelRole.SectionId: result = newQVariant(activityNotificationItem.sectionId)
      of ModelRole.Name: result = newQVariant(activityNotificationItem.name)
      of ModelRole.NewsTitle: result = newQVariant(activityNotificationItem.newsTitle)
      of ModelRole.NewsDescription: result = newQVariant(activityNotificationItem.newsDescription)
      of ModelRole.NewsContent: result = newQVariant(activityNotificationItem.newsContent)
      of ModelRole.NewsImageUrl: result = newQVariant(activityNotificationItem.newsImageUrl)
      of ModelRole.NewsLink: result = newQVariant(activityNotificationItem.newsLink)
      of ModelRole.NewsLinkLabel: result = newQVariant(activityNotificationItem.newsLinkLabel)
      of ModelRole.Author: result = newQVariant(activityNotificationItem.author)
      of ModelRole.NotificationType: result = newQVariant(activityNotificationItem.notificationType.int)
      of ModelRole.Message: result = if not activityNotificationItem.messageItem.isNil:
                                        newQVariant(activityNotificationItem.messageItem)
                                      else:
                                        newQVariant()
      of ModelRole.Timestamp: result = newQVariant(activityNotificationItem.timestamp)
      of ModelRole.PreviousTimestamp: result = newQVariant(if index.row > 0:
                                                              self.items[index.row - 1].timestamp
                                                            else:
                                                              0)
      of ModelRole.Read: result = newQVariant(activityNotificationItem.read.bool)
      of ModelRole.Dismissed: result = newQVariant(activityNotificationItem.dismissed.bool)
      of ModelRole.Accepted: result = newQVariant(activityNotificationItem.accepted.bool)
      of ModelRole.RepliedMessage: result = if not activityNotificationItem.repliedMessageItem.isNil:
                                        newQVariant(activityNotificationItem.repliedMessageItem)
                                      else:
                                        newQVariant()
      of ModelRole.ChatType: result = newQVariant(activityNotificationItem.chatType.int)
      of ModelRole.TokenData: result = newQVariant(activityNotificationItem.tokenDataItem)
      of ModelRole.InstallationId: result = newQVariant(activityNotificationItem.installationId)

  method roleNames(self: Model): Table[int, string] =
    {
      ModelRole.Id.int:"id",
      ModelRole.ChatId.int:"chatId",
      ModelRole.CommunityId.int:"communityId",
      ModelRole.MembershipStatus.int: "membershipStatus",
      ModelRole.SectionId.int: "sectionId",
      ModelRole.Name.int: "name",
      ModelRole.NewsTitle.int: "newsTitle",
      ModelRole.NewsDescription.int: "newsDescription",
      ModelRole.NewsContent.int: "newsContent",
      ModelRole.NewsImageUrl.int: "newsImageUrl",
      ModelRole.NewsLink.int: "newsLink",
      ModelRole.NewsLinkLabel.int: "newsLinkLabel",
      ModelRole.Author.int: "author",
      ModelRole.NotificationType.int: "notificationType",
      ModelRole.Message.int: "message",
      ModelRole.Timestamp.int: "timestamp",
      ModelRole.PreviousTimestamp.int: "previousTimestamp",
      ModelRole.Read.int: "read",
      ModelRole.Dismissed.int: "dismissed",
      ModelRole.Accepted.int: "accepted",
      ModelRole.RepliedMessage.int: "repliedMessage",
      ModelRole.ChatType.int: "chatType",
      ModelRole.TokenData.int: "tokenData",
      ModelRole.InstallationId.int: "installationId",
    }.toTable

  proc findNotificationIndex(self: Model, notificationId: string): int {.slot.} =
    if notificationId.len == 0:
      return -1
    for i in 0 ..< self.items.len:
      if self.items[i].id == notificationId:
        return i
    return -1

  proc markActivityCenterNotificationUnread*(self: Model, notificationId: string) =
    updateItemRolesAndNotify self.findNotificationIndex(notificationId):
      updateRoleWithValue(read, false)

  proc markActivityCenterNotificationRead*(self: Model, notificationId: string) =
    updateItemRolesAndNotify self.findNotificationIndex(notificationId):
      updateRoleWithValue(read, true)

  proc activityCenterNotificationAccepted*(self: Model, notificationId: string) =
    updateItemRolesAndNotify self.findNotificationIndex(notificationId):
      updateRoleWithValue(accepted, true)
      updateRoleWithValue(read, true)

  proc activityCenterNotificationDismissed*(self: Model, notificationId: string) =
    updateItemRolesAndNotify self.findNotificationIndex(notificationId):
      updateRoleWithValue(dismissed, true)
      updateRoleWithValue(read, true)

  proc updateCommunityMembershipStatus*(self: Model, communityId: string, memberPubkey: string, status: ActivityCenterMembershipStatus) =
    for ind, notification in self.items:
      if notification.notificationType == ActivityCenterNotificationType.CommunityMembershipRequest and
          notification.communityId == communityId and
          (notification.author == memberPubkey or notification.chatId == memberPubkey):
        updateRolesAndNotify:
          updateRoleWithValue(membershipStatus, status)

  proc removeNotifications*(self: Model, ids: seq[string]) =
    var i = 0
    var indexesToDelete: seq[int] = @[]
    for activityCenterNotification in self.items:
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
      self.items.delete(indexUpdated)
      self.endRemoveRows()
      i = i + 1

  proc setNewData*(self: Model, activityCenterNotifications: seq[Item]) =
    self.beginResetModel()
    self.items = activityCenterNotifications
    self.endResetModel()

  proc updateActivityCenterNotification*(self: Model, ind: int, newNotification: Item) =
    if self.items[ind].notificationType == ActivityCenterNotificationType.CommunityMembershipRequest and
        self.items[ind].membershipStatus in [
          ActivityCenterMembershipStatus.Accepted,
          ActivityCenterMembershipStatus.Declined,
        ] and
        newNotification.membershipStatus notin [
          ActivityCenterMembershipStatus.Accepted,
          ActivityCenterMembershipStatus.Declined,
        ]:
      newNotification.membershipStatus = self.items[ind].membershipStatus

    updateRolesAndNotify:
      updateRolesFromItem(newNotification,
        id, chatId, communityId, membershipStatus, sectionId, name, newsTitle,
        newsDescription, newsContent, newsImageUrl, newsLink, newsLinkLabel,
        author, notificationType, timestamp, read, dismissed, accepted, chatType,
        installationId)
      updateRoleWithValue(messageItem, newNotification.messageItem, Message)
      updateRoleWithValue(repliedMessageItem, newNotification.repliedMessageItem, RepliedMessage)
      updateRoleWithValue(tokenDataItem, newNotification.tokenDataItem, TokenData)

  proc upsertActivityCenterNotification*(self: Model, newNotification: Item) =
    for i, notification in self.items:
      if newNotification.id == notification.id:
        self.updateActivityCenterNotification(i, newNotification)
        return

    let parentModelIndex = newQModelIndex()
    defer: parentModelIndex.delete

    var indexToInsert = self.items.len
    for i, notification in self.items:
      if newNotification.timestamp > notification.timestamp:
        indexToInsert = i
        break

    self.beginInsertRows(parentModelIndex, indexToInsert, indexToInsert)
    self.items.insert(newNotification, indexToInsert)
    self.endInsertRows()

    let indexToUpdate = indexToInsert - 2
    if indexToUpdate >= 0 and indexToUpdate < self.items.len:
      notifyRangeRolesChanged(indexToUpdate, indexToUpdate, @[ModelRole.PreviousTimestamp.int])

  proc upsertActivityCenterNotifications*(self: Model, activityCenterNotifications: seq[Item]) =
    if self.items.len == 0:
      self.setNewData(activityCenterNotifications)
    else:
      for activityCenterNotification in activityCenterNotifications:
        self.upsertActivityCenterNotification(activityCenterNotification)

  proc setup(self: Model) =
    self.QAbstractListModel.setup
  proc delete(self: Model) =
    self.QAbstractListModel.delete
