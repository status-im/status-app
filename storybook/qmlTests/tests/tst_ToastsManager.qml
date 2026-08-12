import QtQuick
import QtTest

import AppLayouts.stores
import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Profile.stores
import shared.stores as SharedStores

import mainui
import utils

Item {
    id: root
    width: 400
    height: 400

    RootStore {
        id: mockRootStore

        property int notificationCount: 0
        property var notifications: []

        function clearNotifications() {
            notifications = []
            notificationCount = 0
        }

        function displayEphemeralNotification(title, subTitle, image, icon, iconColor,
                                              loading, ephNotifType, actionType, actionData, url) {
            notifications = notifications.concat([{
                                                      title: title,
                                                      subTitle: subTitle,
                                                      image: image,
                                                      icon: icon,
                                                      iconColor: iconColor,
                                                      loading: loading,
                                                      ephNotifType: ephNotifType,
                                                      actionType: actionType,
                                                      actionData: actionData,
                                                      url: url
                                                  }])
            notificationCount = notifications.length
        }
    }

    ContactsStore {
        id: mockContactsStore
        signal contactRemoved(string displayName, bool theyRemovedUs)
    }

    ChatStores.RootStore {
        id: mockChatStore
    }

    SharedStores.CommunityTokensStore {
        id: mockCommunityTokensStore
        signal ownershipLost(string communityId, string communityName)
    }

    ProfileStore {
        id: mockProfileStore
        signal profileSettingsSaveSucceeded()
        signal profileSettingsSaveFailed()
    }

    DevicesStore {
        id: mockDevicesStore
        signal localBackupExportCompleted(bool success)
        signal localBackupImportCompleted(bool success)
    }

    Component {
        id: managerComponent
        ToastsManager {
            rootStore: mockRootStore
            contactsStore: mockContactsStore
            rootChatStore: mockChatStore
            communityTokensStore: mockCommunityTokensStore
            profileStore: mockProfileStore
            devicesStore: mockDevicesStore
        }
    }

    property var manager: null

    TestCase {
        name: "ToastsManager"
        when: windowShown

        function init() {
            mockRootStore.clearNotifications()
            manager = createTemporaryObject(managerComponent, root)
            verify(!!manager)
        }

        function cleanup() {
            manager = null
            mockRootStore.clearNotifications()
        }

        function lastNotification() {
            return mockRootStore.notifications[mockRootStore.notifications.length - 1]
        }

        function test_contactRemoved_forwardsToast() {
            mockContactsStore.contactRemoved("Alice", false)
            tryCompare(mockRootStore, "notificationCount", 1)

            const toast = lastNotification()
            compare(toast.title, "Contact removed")
            compare(toast.subTitle, "You removed Alice as a contact")
            compare(toast.icon, "checkmark-circle")
            compare(toast.ephNotifType, Constants.ephemeralNotificationType.success)
            verify(!toast.loading)
        }

        function test_contactRemovedByThem_forwardsToast() {
            mockContactsStore.contactRemoved("Bob", true)
            tryCompare(mockRootStore, "notificationCount", 1)

            const toast = lastNotification()
            compare(toast.title, "Contact removed")
            compare(toast.subTitle, "Bob removed you as a contact")
            compare(toast.icon, "warning")
            compare(toast.ephNotifType, Constants.ephemeralNotificationType.danger)
        }

        function test_profileSettingsSaveSucceeded_forwardsToast() {
            mockProfileStore.profileSettingsSaveSucceeded()
            tryCompare(mockRootStore, "notificationCount", 1)

            const toast = lastNotification()
            compare(toast.title, "Profile changes saved")
            compare(toast.icon, "checkmark-circle")
            compare(toast.ephNotifType, Constants.ephemeralNotificationType.success)
        }

        function test_profileSettingsSaveFailed_forwardsToast() {
            mockProfileStore.profileSettingsSaveFailed()
            tryCompare(mockRootStore, "notificationCount", 1)

            const toast = lastNotification()
            compare(toast.title, "Profile changes could not be saved")
            compare(toast.icon, "warning")
            compare(toast.ephNotifType, Constants.ephemeralNotificationType.danger)
        }

        function test_localBackupImportCompleted_forwardsToast() {
            mockDevicesStore.localBackupImportCompleted(true)
            tryCompare(mockRootStore, "notificationCount", 1)
            compare(lastNotification().title, "Your data backup restored successfully")
            compare(lastNotification().ephNotifType, Constants.ephemeralNotificationType.success)

            mockRootStore.clearNotifications()
            mockDevicesStore.localBackupImportCompleted(false)
            tryCompare(mockRootStore, "notificationCount", 1)
            compare(lastNotification().title,
                    "Import failed. Make sure the backup file matches your profile name.")
            compare(lastNotification().icon, "warning")
            compare(lastNotification().ephNotifType, Constants.ephemeralNotificationType.danger)
        }

        function test_localBackupExportFailed_forwardsToast() {
            mockDevicesStore.localBackupExportCompleted(false)
            tryCompare(mockRootStore, "notificationCount", 1)

            const toast = lastNotification()
            compare(toast.title, "Backup failed")
            compare(toast.icon, "warning")
            compare(toast.ephNotifType, Constants.ephemeralNotificationType.danger)
            compare(toast.url, "#%1/%2"
                    .arg(Constants.appSection.profile)
                    .arg(Constants.settingsSubsection.backupSettings))
        }

        function test_localBackupExportSucceeded_silent() {
            mockDevicesStore.localBackupExportCompleted(true)
            compare(mockRootStore.notificationCount, 0)
        }

        function test_ownershipLost_forwardsToast() {
            mockCommunityTokensStore.ownershipLost("cid", "MyCommunity")
            tryCompare(mockRootStore, "notificationCount", 1)

            const toast = lastNotification()
            verify(toast.title.indexOf("MyCommunity") !== -1)
            compare(toast.icon, "crown-off")
            compare(toast.ephNotifType, Constants.ephemeralNotificationType.danger)
        }
    }
}
