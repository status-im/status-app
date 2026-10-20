import StatusQ.Core.Utils

import utils

import QtModelsToolkit

/**
  * Wrapper over generic ModelEntry to expose entries from model of notifications.
  */
QObject {
    id: root

    required property string notificationId
    required property var activityCenterNotifications

    readonly property ActivityNotification notification: ActivityNotification {
        readonly property var entry: itemData.item

        notificationId: root.notificationId
        chatId: entry.chatId ?? ""
        threadId: entry.threadId ?? ""
        threadName: entry.threadName ?? ""
        communityId: entry.communityId ?? ""
        membershipStatus: entry.membershipStatus ?? 0
        sectionId: entry.sectionId ?? ""
        name: ensName
        newsTitle: entry.newsTitle ?? ""
        newsDescription: entry.newsDescription ?? ""
        newsContent: entry.newsContent ?? ""
        newsImageUrl: entry.newsImageUrl ?? ""
        newsLink: entry.newsLink ?? ""
        newsLinkLabel: entry.newsLinkLabel ?? ""
        author: entry.author ?? ""
        notificationType: entry.notificationType ?? 0
        message: entry.message ?? null
        timestamp: entry.timestamp ?? 0
        previousTimestamp: entry.previousTimestamp ?? 0
        read: entry.read ?? false
        dismissed: entry.dismissed ?? false
        accepted: entry.accepted ?? false
        repliedMessage: entry.repliedMessage ?? null
        chatType: entry.chatType ?? 0
        tokenData: entry.tokenData ?? null
        installationId: entry.installationId ?? ""
    }

    ModelEntry {
        id: itemData
        sourceModel: root.activityCenterNotifications
        key: "id"
        value: root.notificationId
    }
}
