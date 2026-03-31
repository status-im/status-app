import json
import core, ../app_service/common/utils
import response_type

export response_type

proc registerForPushNotifications*(deviceToken: string, apnTopic: string, tokenType: int):
  RpcResponse[JsonNode] =
  let payload = %* [deviceToken, apnTopic, tokenType]
  result = callPrivateRPC("registerForPushNotifications".prefix, payload)

proc unregisterFromPushNotifications*(): RpcResponse[JsonNode] =
  result = callPrivateRPC("unregisterFromPushNotifications".prefix, %* [])

proc enablePushNotificationsFromContactsOnly*(): RpcResponse[JsonNode] =
  result = callPrivateRPC("enablePushNotificationsFromContactsOnly".prefix, %* [])

proc disablePushNotificationsFromContactsOnly*(): RpcResponse[JsonNode] =
  result = callPrivateRPC("disablePushNotificationsFromContactsOnly".prefix, %* [])

proc enablePushNotificationsBlockMentions*(): RpcResponse[JsonNode] =
  result = callPrivateRPC("enablePushNotificationsBlockMentions".prefix, %* [])

proc disablePushNotificationsBlockMentions*(): RpcResponse[JsonNode] =
  result = callPrivateRPC("disablePushNotificationsBlockMentions".prefix, %* [])
