import QtQuick

import StatusQ.Core.Utils as SQUtils

import AppLayouts.Profile.stores as ProfileStores

import shared.popups
import utils

import MobileUI

EnablePushNotificationsPopup {
    id: root

    required property ProfileStores.NotificationsStore notificationsStore

    hasPermission: PushNotifications.status === PushNotifications.Granted &&
                   root.notificationsStore.notificationsSettings.remotePushNotificationsEnabled

    function requestPermission() {
        pushNotificationsConnections.enabled = true
        PushNotifications.request()
        root.loading = true
    }

    onEnablePushNotifications: {
        if (SQUtils.Utils.isIOS) {
            root.notificationsStore.notificationsSettings.remotePushNotificationsEnabled = true
        } else {
            root.notificationsStore.notificationsSettings.notifSettingAllowNotifications = true
        }
        if (PushNotifications.status !== PushNotifications.Granted)
            root.requestPermission()
    }

    onOpenSettingsRequested: {
        PushNotifications.openSettings()
        root.close()
    }

    Connections {
        id: pushNotificationsConnections
        target: PushNotifications

        function onStatusChanged() {
            root.loading = false
            root.hasPermission = PushNotifications.status === PushNotifications.Granted

            if (PushNotifications.status === PushNotifications.Granted) {
                Global.displayToastMessage(
                    qsTranslate("HandlersManager", "Push notifications enabled"),
                    "",
                    "checkmark-circle",
                    false,
                    Constants.ephemeralNotificationType.success,
                    ""
                )
                root.close()
                pushNotificationsConnections.enabled = false
                return
            }
        }
    }
}
