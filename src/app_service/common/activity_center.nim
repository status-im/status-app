import json, json_serialization
import ../../app/core/eventemitter

include json_utils

const SIGNAL_PARSE_RAW_ACTIVITY_CENTER_NOTIFICATIONS* = "parseRawActivityCenterNotifications"

type RawActivityCenterNotificationsArgs* = ref object of Args
  activityCenterNotifications*: JsonNode

proc checkAndEmitACNotificationsFromResponse*(events: EventEmitter, activityCenterNotifications: JsonNode) =
  if activityCenterNotifications == nil or activityCenterNotifications.kind == JNull:
    return

  # Downstream consumers iterate as a JSON array. Some RPC responses wrap
  # notifications in an object payload, so normalize before emitting.
  if activityCenterNotifications.kind == JObject:
    var notifications: JsonNode
    if activityCenterNotifications.getProp("notifications", notifications):
      if notifications.kind != JArray:
        return
      events.emit(SIGNAL_PARSE_RAW_ACTIVITY_CENTER_NOTIFICATIONS,
        RawActivityCenterNotificationsArgs(activityCenterNotifications: notifications))
      return

    # No array payload available.
    return

  if activityCenterNotifications.kind != JArray:
    return

  events.emit(SIGNAL_PARSE_RAW_ACTIVITY_CENTER_NOTIFICATIONS,
    RawActivityCenterNotificationsArgs(activityCenterNotifications: activityCenterNotifications))