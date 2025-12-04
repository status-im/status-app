import QtQuick

import shared

QtObject {
    id: root

    enum ActivityCenterReadType {
        Read = 1,
        Unread = 2,
        All = 3
    }

    readonly property var activityCenterModuleInst: activityCenterModule
    readonly property var activityCenterNotifications: activityCenterModuleInst.activityNotificationsModel

    readonly property int unreadNotificationsCount: activityCenterModuleInst.unreadActivityCenterNotificationsCount
    readonly property bool hasUnseenNotifications: activityCenterModuleInst.hasUnseenActivityCenterNotifications
    readonly property int activeNotificationGroup: activityCenterModuleInst.activeNotificationGroup
    readonly property int activityCenterReadType: activityCenterModuleInst.activityCenterReadType

    readonly property int adminCount: activityCenterModuleInst.adminCount
    readonly property int mentionsCount: activityCenterModuleInst.mentionsCount
    readonly property int repliesCount: activityCenterModuleInst.repliesCount
    readonly property int contactRequestsCount: activityCenterModuleInst.contactRequestsCount
    readonly property int membershipCount: activityCenterModuleInst.membershipCount

    function markAllActivityCenterNotificationsRead() {
        root.activityCenterModuleInst.markAllActivityCenterNotificationsRead()
    }

    function markActivityCenterNotificationRead(notificationId) {
        root.activityCenterModuleInst.markActivityCenterNotificationRead(notificationId)
    }

    function markActivityCenterNotificationUnread(notificationId) {
        root.activityCenterModuleInst.markActivityCenterNotificationUnread(notificationId)
    }

    function markAsSeenActivityCenterNotifications() {
        root.activityCenterModuleInst.markAsSeenActivityCenterNotifications()
    }

    function switchTo(sectionId, chatId, messageId) {
        root.activityCenterModuleInst.switchTo(sectionId, chatId, messageId)
    }

    function setActiveNotificationGroup(group) {
        root.activityCenterModuleInst.setActiveNotificationGroup(group)
    }

    function setActivityCenterReadType(readType) {
        root.activityCenterModuleInst.setActivityCenterReadType(readType)
    }

    function fetchActivityCenterNotifications() {
        root.activityCenterModuleInst.fetchActivityCenterNotifications()
    }

    function acceptActivityCenterNotification(notificationId) {
        root.activityCenterModuleInst.acceptActivityCenterNotification(notificationId)
    }

    function dismissActivityCenterNotification(notificationId) {
        root.activityCenterModuleInst.dismissActivityCenterNotification(notificationId)
    }

    function enableInstallationAndSync(installationId) {
        root.activityCenterModuleInst.enableInstallationAndSync(installationId)
    }
}
