import QtQuick

import shared.popups
import utils

import MobileUI

EnablePushNotificationsPopup {
    id: root

    destroyOnClose: true

    function requestPermission() {
        pushNotificationsConnections.enabled = true
        PushNotifications.request()
        root.loading = true
    }

    Connections {
        id: pushNotificationsConnections
        target: PushNotifications

        function onStatusChanged() {
            root.loading = false
            root.hasPermission = PushNotifications.status === PushNotifications.Granted

            if (PushNotifications.status === PushNotifications.Granted) {
                Global.displayToastMessage(
                    qsTr("Push notifications enabled"),
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
