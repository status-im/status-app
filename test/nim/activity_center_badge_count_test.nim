import unittest

import app_service/service/activity_center/dto/notification
import app_service/service/activity_center/service

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
