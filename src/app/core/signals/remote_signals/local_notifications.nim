import json

import base
import signal_type

type LocalNotificationSignal* = ref object of Signal
  id*: string
  category*: string
  conversationId*: string
  displayTitle*: string
  displayMessage*: string
  title*: string
  message*: string
  deepLink*: string
  isFromMe*: bool
  deleted*: bool
  # Avatar/icon images as base64 data URIs, resolved by status-go from raw image bytes
  # (or identicon). These are the authoritative source for notification images — the
  # contact/community services only expose media-server URLs. Same fields Android consumes.
  authorIcon*: string
  authorName*: string
  communityIcon*: string
  chatIcon*: string

proc fromEvent*(T: type LocalNotificationSignal, jsonSignal: JsonNode): LocalNotificationSignal =
  result = LocalNotificationSignal()
  result.signalType = SignalType.LocalNotifications
  if jsonSignal["event"].kind != JNull:
    result.id = jsonSignal["event"]{"id"}.getStr()
    result.category = jsonSignal["event"]{"category"}.getStr()
    result.conversationId = jsonSignal["event"]{"conversationId"}.getStr()
    result.displayTitle = jsonSignal["event"]{"displayTitle"}.getStr()
    result.displayMessage = jsonSignal["event"]{"displayMessage"}.getStr()
    result.title = jsonSignal["event"]{"title"}.getStr()
    result.message = jsonSignal["event"]{"message"}.getStr()
    result.deepLink = jsonSignal["event"]{"deepLink"}.getStr()
    result.isFromMe = jsonSignal["event"]{"isFromMe"}.getBool()
    result.deleted = jsonSignal["event"]{"deleted"}.getBool()
    result.communityIcon = jsonSignal["event"]{"communityIcon"}.getStr()
    result.chatIcon = jsonSignal["event"]{"chatIcon"}.getStr()
    result.authorIcon = jsonSignal["event"]{"notificationAuthor"}{"icon"}.getStr()
    result.authorName = jsonSignal["event"]{"notificationAuthor"}{"name"}.getStr()
