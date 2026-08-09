include ../../common/json_utils
include ../../../app/core/tasks/common

type
  AsyncActivityNotificationLoadTaskArg = ref object of QObjectTaskArg
    cursor: string
    limit: int
    group: ActivityCenterGroup
    readType: ActivityCenterReadType

  AsyncActivityCenterCountsTaskArg = ref object of QObjectTaskArg
    generation: int
    readType: ActivityCenterReadType

proc asyncActivityNotificationLoadTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncActivityNotificationLoadTaskArg](argEncoded)
  try:
    let activityTypes = activityCenterNotificationTypesByGroup(arg.group)
    let activityNotificationsCallResult = backend.activityCenterNotifications(
      backend.ActivityCenterNotificationsRequest(
        cursor: arg.cursor,
        limit: arg.limit,
        activityTypes: activityTypes,
        readType: arg.readType.int
      )
    )
    arg.finish(%*{
      "activityNotifications": activityNotificationsCallResult.result,
      "error": activityNotificationsCallResult.error,
    })
  except Exception as e:
    arg.finish(%* {
      "error": e.msg,
    })

proc asyncActivityCenterCountsTask(argEncoded: string) {.gcsafe, nimcall.} =
  let arg = decode[AsyncActivityCenterCountsTaskArg](argEncoded)
  try:
    let activityTypes = activityCenterNotificationTypesByGroup(ActivityCenterGroup.All)
    let currentCountersResponse = backend.activityCenterNotificationsCount(
      backend.ActivityCenterCountRequest(
        activityTypes: activityTypes,
        readType: arg.readType.int,
      )
    )
    if currentCountersResponse.error != nil:
      arg.finish(%*{
        "generation": arg.generation,
        "readType": arg.readType.int,
        "error": currentCountersResponse.error.message,
      })
      return

    var unreadCounters = currentCountersResponse.result
    if arg.readType != ActivityCenterReadType.Unread:
      let unreadCountersResponse = backend.activityCenterNotificationsCount(
        backend.ActivityCenterCountRequest(
          activityTypes: activityTypes,
          readType: ActivityCenterReadType.Unread.int,
        )
      )
      if unreadCountersResponse.error != nil:
        arg.finish(%*{
          "generation": arg.generation,
          "readType": arg.readType.int,
          "error": unreadCountersResponse.error.message,
        })
        return
      unreadCounters = unreadCountersResponse.result

    arg.finish(%*{
      "generation": arg.generation,
      "readType": arg.readType.int,
      "currentCounters": currentCountersResponse.result,
      "unreadCounters": unreadCounters,
      "error": "",
    })
  except Exception as e:
    arg.finish(%*{
      "generation": arg.generation,
      "readType": arg.readType.int,
      "error": e.msg,
    })
