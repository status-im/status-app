import std/tables
import unittest

import app_service/service/activity_center/count_snapshot
import app_service/service/activity_center/dto/notification

suite "activity center badge count":
  test "non-messaging types exclude only mentions and replies":
    let allTypes = activityCenterNotificationTypesByGroup(ActivityCenterGroup.All)
    let nonMessagingTypes = activityCenterNotificationTypesByGroup(ActivityCenterGroup.NonMessaging)

    check ActivityCenterNotificationType.Mention.int notin nonMessagingTypes
    check ActivityCenterNotificationType.Reply.int notin nonMessagingTypes
    check nonMessagingTypes.len == allTypes.len - 2

    for activityType in allTypes:
      if activityType != ActivityCenterNotificationType.Mention.int and
          activityType != ActivityCenterNotificationType.Reply.int:
        check activityType in nonMessagingTypes

  test "count snapshot derives group and unread totals":
    var currentCounters = initTable[int, int]()
    currentCounters[ActivityCenterNotificationType.Mention.int] = 2
    currentCounters[ActivityCenterNotificationType.Reply.int] = 3
    currentCounters[ActivityCenterNotificationType.ContactRequest.int] = 5

    var unreadCounters = initTable[int, int]()
    unreadCounters[ActivityCenterNotificationType.Mention.int] = 7
    unreadCounters[ActivityCenterNotificationType.Reply.int] = 11
    unreadCounters[ActivityCenterNotificationType.ContactRequest.int] = 13

    let snapshot = buildActivityCenterCountSnapshot(currentCounters, unreadCounters)

    check snapshot.groupCounters[ActivityCenterGroup.Mentions] == 2
    check snapshot.groupCounters[ActivityCenterGroup.Replies] == 3
    check snapshot.groupCounters[ActivityCenterGroup.ContactRequests] == 5
    check snapshot.groupCounters[ActivityCenterGroup.News] == 0
    check snapshot.unreadCount == 31
    check snapshot.unreadNonMessagingCount == 13
