import nimqml, json, chronicles
import dotherside_ext

import ../../global/app_signals
import ../../global/global_singleton
import ../eventemitter
import ../../../app_service/service/settings/service as settings_service
import details

export details

logScope:
  topics = "notifications-manager"

# Signals which may be emitted by this class:
const SIGNAL_DISPLAY_APP_NOTIFICATION* = "displayAppNotification"
const SIGNAL_DISPLAY_WINDOWS_OS_NOTIFICATION* = "displayWindowsOsNotification"
const SIGNAL_OS_NOTIFICATION_CLICKED* = "osNotificationClicked"
const SIGNAL_PLAY_NOTIFICATION_SOUND* = "playNotificationSound"

# Anonymous preferences
const PREVIEW_ANONYMOUS = 0
const PREVIEW_NAME_ONLY = 1

type
  NotificationArgs* = ref object of Args
    title*: string
    message*: string
    identifier*: string
    details*: NotificationDetails

  ClickedNotificationArgs* = ref object of Args
    details*: NotificationDetails

QtObject:
  type NotificationsManager* = ref object of QObject
    events: EventEmitter
    settingsService: settings_service.Service
    osNotification: StatusOSNotification
    notificationSetUp: bool

  proc processNotification(self: NotificationsManager, title: string, message: string, details: NotificationDetails)

  proc setup(self: NotificationsManager, events: EventEmitter, settingsService: settings_service.Service)

  proc highestNotifSetting(a, b: string): string =
    ## Returns whichever of the two notification settings has the highest priority.
    ## Priority order (highest first): SendAlerts > DeliverQuietly > TurnOff
    if a == VALUE_NOTIF_SEND_ALERTS or b == VALUE_NOTIF_SEND_ALERTS:
      return VALUE_NOTIF_SEND_ALERTS
    if a == VALUE_NOTIF_DELIVER_QUIETLY or b == VALUE_NOTIF_DELIVER_QUIETLY:
      return VALUE_NOTIF_DELIVER_QUIETLY
    return VALUE_NOTIF_TURN_OFF

  proc delete*(self: NotificationsManager)
  proc newNotificationsManager*(events: EventEmitter, settingsService: settings_service.Service): NotificationsManager =
    new(result, delete)
    result.setup(events, settingsService)

  proc onAppReady*(self: NotificationsManager) =
    self.osNotification = newStatusOSNotification()

    signalConnect(self.osNotification, "notificationClicked(QString)", self, "onOSNotificationClicked(QString)", 2)
    signalConnect(singletonInstance.globalEvents, "showTestNotification(QString, QString)",
      self, "onShowTestNotification(QString, QString)", 2)
    signalConnect(singletonInstance.globalEvents, "showMessageNotification(QString, QString, QString, bool, bool, QString, bool, QString, int, bool, bool)",
      self, "onShowMessageNotification(QString, QString, QString, bool, bool, QString, bool, QString, int, bool, bool)", 2)
    signalConnect(singletonInstance.globalEvents, "showNewContactRequestNotification(QString, QString, QString)",
      self, "onShowNewContactRequestNotification(QString, QString, QString)", 2)
    signalConnect(singletonInstance.globalEvents, "showAcceptedContactRequest(QString, QString, QString)",
      self, "onShowAcceptedContactRequest(QString, QString, QString)", 2)
    signalConnect(singletonInstance.globalEvents, "showContactRemoved(QString, QString, QString)",
      self, "onShowContactRemoved(QString, QString, QString)", 2)
    signalConnect(singletonInstance.globalEvents, "newCommunityMembershipRequestNotification(QString, QString, QString)",
      self, "onNewCommunityMembershipRequestNotification(QString, QString, QString)", 2)
    signalConnect(singletonInstance.globalEvents, "myRequestToJoinCommunityAcccepted(QString, QString, QString)",
      self, "onMyRequestToJoinCommunityAcccepted(QString, QString, QString)", 2)
    signalConnect(singletonInstance.globalEvents, "myRequestToJoinCommunityRejected(QString, QString, QString)",
      self, "onMyRequestToJoinCommunityRejected(QString, QString, QString)", 2)
    signalConnect(singletonInstance.globalEvents, "meMentionedIconBadgeNotification(int)",
      self, "onMeMentionedIconBadgeNotification(int)", 2)
    signalConnect(singletonInstance.globalEvents, "showCommunityTokenPermissionCreatedNotification(QString, QString, QString)", self, "onShowCommunityTokenPermissionCreatedNotification(QString, QString, QString)", 2)
    signalConnect(singletonInstance.globalEvents, "showCommunityTokenPermissionUpdatedNotification(QString, QString, QString)", self, "onShowCommunityTokenPermissionUpdatedNotification(QString, QString, QString)", 2)
    signalConnect(singletonInstance.globalEvents, "showCommunityTokenPermissionDeletedNotification(QString, QString, QString)", self, "onShowCommunityTokenPermissionDeletedNotification(QString, QString, QString)", 2)
    signalConnect(singletonInstance.globalEvents, "showCommunityTokenPermissionCreationFailedNotification(QString, QString, QString)", self, "onShowCommunityTokenPermissionCreationFailedNotification(QString, QString, QString)", 2)
    signalConnect(singletonInstance.globalEvents, "showCommunityTokenPermissionUpdateFailedNotification(QString, QString, QString)", self, "onShowCommunityTokenPermissionUpdateFailedNotification(QString, QString, QString)", 2)
    signalConnect(singletonInstance.globalEvents, "showCommunityTokenPermissionDeletionFailedNotification(QString, QString, QString)", self, "onShowCommunityTokenPermissionDeletionFailedNotification(QString, QString, QString)", 2)
    signalConnect(singletonInstance.globalEvents, "showCommunityMemberKickedNotification(QString, QString, QString)", self, "onShowCommunityMemberKickedNotification(QString, QString, QString)", 2)
    signalConnect(singletonInstance.globalEvents, "showCommunityMemberBannedNotification(QString, QString, QString)", self, "onShowCommunityMemberBannedNotification(QString, QString, QString)", 2)
    signalConnect(singletonInstance.globalEvents, "showCommunityMemberUnbannedNotification(QString, QString, QString)", self, "onShowCommunityMemberUnbannedNotification(QString, QString, QString)", 2)
    signalConnect(singletonInstance.globalEvents, "showNewsMessageNotification(QString, QString)", self, "onShowNewsMessageNotification(QString, QString)", 2)

    self.notificationSetUp = true

  proc init*(self: NotificationsManager) =
    discard

  proc showOSNotification(self: NotificationsManager, title: string, message: string, identifier: string) =
    if defined(windows):
      let data = NotificationArgs(title: title, message: message)
      self.events.emit(SIGNAL_DISPLAY_WINDOWS_OS_NOTIFICATION, data)
    else:
      ## This method will add new notification to the OS Notification center. Param
      ## "identifier" is used to uniquely define notification bubble.
      self.osNotification.showNotification(title, message, identifier)

  proc onOSNotificationClicked(self: NotificationsManager, identifier: string) {.slot.} =
    ## This slot is called once user clicks OS notificaiton bubble, "identifier"
    ## contains data which uniquely define that notification.
    debug "OS notification clicked", identifier=identifier

    # Make the app the top most window.
    app_makeItActive(singletonInstance.engine)

    let details = toNotificationDetails(parseJson(identifier))
    if(details.isEmpty()):
      info "Notification details are empty"
      return
    if(details.notificationType == NotificationType.TestNotification):
      info "Test notification was clicked"
      return

    if(details.notificationType == NotificationType.NewMessage or
      details.notificationType == NotificationType.NewMessageWithPersonalMention or
      details.notificationType == NotificationType.NewMessageWithGlobalMention):
      let data = ActiveSectionChatArgs(sectionId: details.sectionId, chatId: details.chatId, messageId: details.messageId)
      self.events.emit(SIGNAL_MAKE_SECTION_CHAT_ACTIVE, data)
    else:
      self.events.emit(SIGNAL_OS_NOTIFICATION_CLICKED, ClickedNotificationArgs(details: details))

  proc onShowTestNotification(self: NotificationsManager, title: string, message: string) {.slot.} =
    let details = NotificationDetails(notificationType: NotificationType.TestNotification)
    self.processNotification(title, message, details)

  proc onShowMessageNotification(self: NotificationsManager, title: string, message: string, sectionId: string,
    isCommunitySection: bool, isSectionActive: bool, chatId: string, isChatActive: bool, messageId: string,
    notificationType: int, isOneToOne: bool, isGroupChat: bool) {.slot.} =
    let details = NotificationDetails(
      notificationType: notificationType.NotificationType,
      sectionId: sectionId,
      isCommunitySection: isCommunitySection,
      sectionActive: isSectionActive,
      chatId: chatId,
      chatActive: isChatActive,
      isOneToOne: isOneToOne,
      isGroupChat: isGroupChat,
      messageId: messageId)
    self.processNotification(title, message, details)

  proc onShowNewsMessageNotification(self: NotificationsManager, id: string, title: string) {.slot.} =
    let details = NotificationDetails(
      notificationType: NotificationType.NewsFeedMessage,
      notificationId: id,
    )
    self.processNotification(title, message = "", details)

  proc onShowCommunityTokenPermissionCreatedNotification*(self: NotificationsManager, sectionId: string, title: string, message: string) {.slot.} =
    let details = NotificationDetails(notificationType: NotificationType.CommunityTokenPermissionCreated, sectionId: sectionId, isCommunitySection: true)
    self.processNotification(title, message, details)

  proc onShowCommunityTokenPermissionUpdatedNotification*(self: NotificationsManager, sectionId: string, title: string, message: string) {.slot.} =
    let details = NotificationDetails(notificationType: NotificationType.CommunityTokenPermissionUpdated, sectionId: sectionId, isCommunitySection: true)
    self.processNotification(title, message, details)

  proc onShowCommunityTokenPermissionDeletedNotification*(self: NotificationsManager, sectionId: string, title: string, message: string) {.slot.} =
    let details = NotificationDetails(notificationType: NotificationType.CommunityTokenPermissionDeleted, sectionId: sectionId, isCommunitySection: true)
    self.processNotification(title, message, details)

  proc onShowCommunityTokenPermissionCreationFailedNotification*(self: NotificationsManager, sectionId: string, title: string, message: string) {.slot.} =
    let details = NotificationDetails(notificationType: NotificationType.CommunityTokenPermissionCreationFailed, sectionId: sectionId, isCommunitySection: true)
    self.processNotification(title, message, details)

  proc onShowCommunityTokenPermissionUpdateFailedNotification*(self: NotificationsManager, sectionId: string, title: string, message: string) {.slot.} =
    let details = NotificationDetails(notificationType: NotificationType.CommunityTokenPermissionUpdateFailed, sectionId: sectionId, isCommunitySection: true)
    self.processNotification(title, message, details)

  proc onShowCommunityTokenPermissionDeletionFailedNotification*(self: NotificationsManager, sectionId: string, title: string, message: string) {.slot.} =
    let details = NotificationDetails(notificationType: NotificationType.CommunityTokenPermissionDeletionFailed, sectionId: sectionId, isCommunitySection: true)
    self.processNotification(title, message, details)

  proc onShowNewContactRequestNotification*(self: NotificationsManager, title: string, message: string,
    sectionId: string) {.slot.} =
    let details = NotificationDetails(notificationType: NotificationType.NewContactRequest, sectionId: sectionId)
    self.processNotification(title, message, details)

  proc onShowAcceptedContactRequest*(self: NotificationsManager, title: string, message: string,
    sectionId: string) {.slot.} =
    let details = NotificationDetails(notificationType: NotificationType.AcceptedContactRequest, sectionId: sectionId)
    self.processNotification(title, message, details)

  proc onShowContactRemoved*(self: NotificationsManager, title: string, message: string,
    sectionId: string) {.slot.} =
    let details = NotificationDetails(notificationType: NotificationType.ContactRemoved, sectionId: sectionId)
    self.processNotification(title, message, details)

  proc onNewCommunityMembershipRequestNotification*(self: NotificationsManager, title: string, message: string,
    sectionId: string) {.slot.} =
    let details = NotificationDetails(notificationType: NotificationType.JoinCommunityRequest, sectionId: sectionId)
    self.processNotification(title, message, details)

  proc onMyRequestToJoinCommunityAcccepted*(self: NotificationsManager, title: string, message: string,
    sectionId: string) {.slot.} =
    let details = NotificationDetails(notificationType: NotificationType.MyRequestToJoinCommunityAccepted,
    sectionId: sectionId)
    self.processNotification(title, message, details)

  proc onMyRequestToJoinCommunityRejected*(self: NotificationsManager, title: string, message: string,
    sectionId: string) {.slot.} =
    let details = NotificationDetails(notificationType: NotificationType.MyRequestToJoinCommunityRejected,
    sectionId: sectionId)
    self.processNotification(title, message, details)

  proc onMeMentionedIconBadgeNotification(self: NotificationsManager, allMentions: int) {.slot.} =
    self.osNotification.showIconBadgeNotification(allMentions)

  proc onShowCommunityMemberKickedNotification*(self: NotificationsManager, title: string, message: string, sectionId: string) {.slot.} =
    let details = NotificationDetails(notificationType: NotificationType.CommunityMemberKicked, sectionId: sectionId, isCommunitySection: true)
    self.processNotification(title, message, details)

  proc onShowCommunityMemberBannedNotification*(self: NotificationsManager, title: string, message: string, sectionId: string) {.slot.} =
    let details = NotificationDetails(notificationType: NotificationType.CommunityMemberBanned, sectionId: sectionId, isCommunitySection: true)
    self.processNotification(title, message, details)

  proc onShowCommunityMemberUnbannedNotification*(self: NotificationsManager, title: string, message: string, sectionId: string) {.slot.} =
    let details = NotificationDetails(notificationType: NotificationType.CommunityMemberUnbanned, sectionId: sectionId, isCommunitySection: true)
    self.processNotification(title, message, details)

  proc notificationCheck(self: NotificationsManager, title: string, message: string, details: NotificationDetails,
      notificationWay: string) =
    var data = NotificationArgs(title: title, message: message, details: details)

    # An exemption from the diagrams, at least for now, is that we don't need to implement the "Badge Check" block here,
    # cause that's already handled in appropriate modules.

    let appIsActive = app_isActive(singletonInstance.engine)

    if (details.notificationType == NotificationType.NewMessage or
        details.notificationType == NotificationType.NewMessageWithPersonalMention or
        details.notificationType == NotificationType.NewMessageWithGlobalMention) and
        details.sectionActive and
        details.chatActive and appIsActive:
      return

    if appIsActive:
      debug "Add APP notification", notificationType=details.notificationType
      self.events.emit(SIGNAL_DISPLAY_APP_NOTIFICATION, data)

    if notificationWay == VALUE_NOTIF_DELIVER_QUIETLY and
        details.notificationType in [
          NotificationType.NewMessage,
          NotificationType.NewMessageWithPersonalMention,
          NotificationType.NewMessageWithGlobalMention,
          NotificationType.NewContactRequest,
          NotificationType.ContactRemoved,
          NotificationType.IdentityVerificationRequest,
          NotificationType.NewsFeedMessage
        ]:
      return

    if not appIsActive or details.notificationType == NotificationType.TestNotification:
      # Check anonymity level
      if(self.settingsService.getNotificationMessagePreview() == PREVIEW_ANONYMOUS):
        data.title = "Status"
        data.message = "You have a new message"
      elif(self.settingsService.getNotificationMessagePreview() == PREVIEW_NAME_ONLY):
        data.message = "You have a new message"

      let identifier = $(details.toJsonNode())
      debug "Add OS notification", notificationType=details.notificationType, identifier=identifier
      self.showOSNotification(data.title, data.message, identifier)

      if self.settingsService.getNotificationSoundsEnabled():
        self.events.emit(SIGNAL_PLAY_NOTIFICATION_SOUND, Args())

  proc processNotification(self: NotificationsManager, title: string, message: string, details: NotificationDetails) =
    ## This is the main method which need to be called to process an event according to the preferences set in the
    ## "Notifications & Sounds" panel of the "Settings" section.
    ##
    ## This method determines whether a notification need to be displayed or not, what notification to display, whether
    ## to display App or OS notification and/or add notification to Activity Center, what level of anonymous to apply,
    ## whether to play sound or not and so...

    # The flow used here follows these diagrams:
    # - https://drive.google.com/file/d/1L_9c2CMObcDcSuhVUu97s9-_26gtutES/view
    # - https://drive.google.com/file/d/1KmG7lJDJIx6R_HJWeFvMYT2wk32RoTJQ/view

    if(not self.settingsService.getNotifSettingAllowNotifications()):
      return

    # In case of contact request
    if(details.notificationType == NotificationType.NewContactRequest):
      if(self.settingsService.getNotifSettingContactRequests() != VALUE_NOTIF_TURN_OFF):
        self.notificationCheck(title, message, details, self.settingsService.getNotifSettingContactRequests())
        return

    # In case of News message
    elif details.notificationType == NotificationType.NewsFeedMessage:
      let newsSetting = self.settingsService.getNotifSettingStatusNews()
      if newsSetting != VALUE_NOTIF_TURN_OFF:
        self.notificationCheck(title, message, details, newsSetting)
        return

    # In case of new message (regardless it's message with mention or not)
    elif(details.notificationType == NotificationType.NewMessage or
      details.notificationType == NotificationType.NewMessageWithPersonalMention or
      details.notificationType == NotificationType.NewMessageWithGlobalMention):
      if(self.settingsService.getNotifSettingAllMessages() != VALUE_NOTIF_TURN_OFF):
        self.notificationCheck(title, message, details, self.settingsService.getNotifSettingAllMessages())
        return

      let messageBelongsToCommunity = details.isCommunitySection
      if messageBelongsToCommunity:
        let exemptions = self.settingsService.getNotifSettingExemptions(details.sectionId)
        if(exemptions.muteAllMessages):
          return

        if details.notificationType == NotificationType.NewMessageWithPersonalMention and
          exemptions.personalMentions != VALUE_NOTIF_TURN_OFF:
          self.notificationCheck(title, message, details, exemptions.personalMentions)
          return

        if details.notificationType == NotificationType.NewMessageWithGlobalMention and
          exemptions.globalMentions != VALUE_NOTIF_TURN_OFF:
          self.notificationCheck(title, message, details, exemptions.globalMentions)
          return

        if details.notificationType == NotificationType.NewMessage and
          exemptions.otherMessages != VALUE_NOTIF_TURN_OFF:
          self.notificationCheck(title, message, details, exemptions.otherMessages)
          return

        return
      else:
        if details.isOneToOne or details.isGroupChat:
          let exemptions = self.settingsService.getNotifSettingExemptions(details.chatId)
          if exemptions.muteAllMessages:
            # Chat is muted
            return

          let chatNotificationWay = if details.isOneToOne:
              self.settingsService.getNotifSettingOneToOneChats()
            else:
              self.settingsService.getNotifSettingGroupChats()

          if details.notificationType == NotificationType.NewMessageWithPersonalMention:
            # A notification should be sent if either the personal mention setting or the chat-type
            # setting allows it. Use whichever of the two is the highest priority.
            let mentionSetting = self.settingsService.getNotifSettingPersonalMentions()
            let effectiveSetting = highestNotifSetting(mentionSetting, chatNotificationWay)
            if effectiveSetting != VALUE_NOTIF_TURN_OFF:
              self.notificationCheck(title, message, details, effectiveSetting)
          else:
            if chatNotificationWay != VALUE_NOTIF_TURN_OFF:
              self.notificationCheck(title, message, details, chatNotificationWay)
          return

        # Personal mentions in non-1-1/non-group-chat contexts (e.g. unnamed channels)
        if details.notificationType == NotificationType.NewMessageWithPersonalMention and
          self.settingsService.getNotifSettingPersonalMentions() != VALUE_NOTIF_TURN_OFF:
          self.notificationCheck(title, message, details, self.settingsService.getNotifSettingPersonalMentions())
          return

        # Global mentions in non-1-1/non-group-chat contexts
        if details.notificationType == NotificationType.NewMessageWithGlobalMention and
          self.settingsService.getNotifSettingGlobalMentions() != VALUE_NOTIF_TURN_OFF:
          self.notificationCheck(title, message, details, self.settingsService.getNotifSettingGlobalMentions())
          return

    # In all other cases (TestNotification, AcceptedContactRequest, ContactRemoved, JoinCommunityRequest,  MyRequestToJoinCommunityAccepted,
    # MyRequestToJoinCommunityRejected)
    else:
      self.notificationCheck(title, message, details, "")

  proc setup(self: NotificationsManager, events: EventEmitter, settingsService: settings_service.Service) =
    self.QObject.setup
    self.events = events
    self.settingsService = settingsService

  proc delete*(self: NotificationsManager) =
    self.QObject.delete

