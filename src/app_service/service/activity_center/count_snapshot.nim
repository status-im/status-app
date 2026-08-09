import std/tables

import ./dto/notification

const COUNTED_ACTIVITY_GROUPS* = @[
  ActivityCenterGroup.Mentions,
  ActivityCenterGroup.Replies,
  ActivityCenterGroup.Membership,
  ActivityCenterGroup.Admin,
  ActivityCenterGroup.ContactRequests,
  ActivityCenterGroup.IdentityVerification,
  ActivityCenterGroup.System,
  ActivityCenterGroup.News
]

type ActivityCenterCountSnapshot* = object
  groupCounters*: Table[ActivityCenterGroup, int]
  unreadCount*: int
  unreadNonMessagingCount*: int

proc sumCounts(counters: Table[int, int], activityTypes: openArray[int]): int =
  for activityType in activityTypes:
    result += counters.getOrDefault(activityType, 0)

proc buildActivityCenterCountSnapshot*(
    currentReadTypeCounters: Table[int, int],
    unreadCounters: Table[int, int],
    ): ActivityCenterCountSnapshot =
  result.groupCounters = initTable[ActivityCenterGroup, int]()
  for group in COUNTED_ACTIVITY_GROUPS:
    result.groupCounters[group] = sumCounts(
      currentReadTypeCounters,
      activityCenterNotificationTypesByGroup(group),
    )

  result.unreadCount = sumCounts(
    unreadCounters,
    activityCenterNotificationTypesByGroup(ActivityCenterGroup.All),
  )
  result.unreadNonMessagingCount = sumCounts(
    unreadCounters,
    activityCenterNotificationTypesByGroup(ActivityCenterGroup.NonMessaging),
  )