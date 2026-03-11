import nimqml

QtObject:
  type GlobalEvents* = ref object of QObject

  proc setup(self: GlobalEvents)
  proc delete*(self: GlobalEvents)
  proc newGlobalEvents*(): GlobalEvents =
    new(result, delete)
    result.setup

  proc setup(self: GlobalEvents) =
    self.QObject.setup

  proc delete*(self: GlobalEvents) =
    self.QObject.delete

  proc showTestNotification*(self: GlobalEvents, title: string, message: string) {.signal.}

  proc showCommunityTokenPermissionCreatedNotification*(self: GlobalEvents, sectionId: string, title: string, message: string) {.signal.}

  proc showCommunityTokenPermissionUpdatedNotification*(self: GlobalEvents, sectionId: string, title: string, message: string) {.signal.}

  proc showCommunityTokenPermissionDeletedNotification*(self: GlobalEvents, sectionId: string, title: string, message: string) {.signal.}

  proc showCommunityTokenPermissionCreationFailedNotification*(self: GlobalEvents, sectionId: string, title: string, message: string) {.signal.}

  proc showCommunityTokenPermissionUpdateFailedNotification*(self: GlobalEvents, sectionId: string, title: string, message: string) {.signal.}

  proc showCommunityTokenPermissionDeletionFailedNotification*(self: GlobalEvents, sectionId: string, title: string, message: string) {.signal.}

  proc showMessageNotification*(self: GlobalEvents, title: string, message: string, sectionId: string,
    isCommunitySection: bool, isSectionActive: bool, chatId: string, isChatActive: bool, messageId: string,
    notificationType: int, isOneToOne: bool, isGroupChat: bool) {.signal.}

  proc showNewContactRequestNotification*(self: GlobalEvents, title: string, message: string,
    sectionId: string) {.signal.}

  proc showAcceptedContactRequest*(self: GlobalEvents, title: string, message: string,
    sectionId: string) {.signal.}

  proc showContactRemoved*(self: GlobalEvents, title: string, message: string,
    sectionId: string) {.signal.}

  proc newCommunityMembershipRequestNotification*(self: GlobalEvents, title: string, message: string,
    sectionId: string) {.signal.}

  proc myRequestToJoinCommunityAcccepted*(self: GlobalEvents, title: string, message: string,
    sectionId: string) {.signal.}

  proc myRequestToJoinCommunityRejected*(self: GlobalEvents, title: string, message: string,
    sectionId: string) {.signal.}

  proc meMentionedIconBadgeNotification*(self: GlobalEvents, allMentions: int) {.signal.}

  proc showCommunityMemberKickedNotification*(self: GlobalEvents, sectionId: string, title: string, message: string) {.signal.}

  proc showCommunityMemberBannedNotification*(self: GlobalEvents, sectionId: string, title: string, message: string) {.signal.}

  proc showCommunityMemberUnbannedNotification*(self: GlobalEvents, sectionId: string, title: string, message: string) {.signal.}

  proc showNewsMessageNotification*(self: GlobalEvents, id: string, title: string) {.signal.}
