import nimqml
import statusq_bridge

type StatusOSNotification* = ref object of QObject

proc delete*(self: StatusOSNotification)

proc newStatusOSNotification*(): StatusOSNotification =
  new(result, delete)
  result.vptr = statusq_osnotification_create()

proc delete*(self: StatusOSNotification) =
  if not self.vptr.isNil:
    statusq_osnotification_delete(self.vptr)
    self.vptr = nil

proc showNotification*(self: StatusOSNotification, title: string, message: string, identifier: string) =
  statusq_osnotification_show_notification(self.vptr, title.cstring, message.cstring, identifier.cstring)

proc showIconBadgeNotification*(self: StatusOSNotification, notificationsCount: int) =
  statusq_osnotification_show_badge_notification(self.vptr, notificationsCount.cint)
