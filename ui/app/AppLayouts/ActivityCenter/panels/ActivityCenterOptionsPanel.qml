import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Core
import StatusQ.Popups

import utils

// It will be reworked on task https://github.com/status-im/status-app/issues/18906
StatusMenu {
    id: root

    required property bool hasUnreadNotifications
    required property bool hideReadNotifications

    signal markAllAsReadRequested()
    signal hideShowReadNotificationsRequested()

    StatusAction {
        visibleOnDisabled: true
        enabled: root.hasUnreadNotifications
        text: qsTr("Mark all as read")
        icon.name: "double-checkmark"
        onTriggered: root.markAllAsReadRequested()
    }

    StatusAction {
        text: !root.hideReadNotifications ? qsTr("Hide read notifications") :
                                           qsTr("Show read notifications")
        icon.name: !root.hideReadNotifications ? "hide" : "show"
        onTriggered: root.hideShowReadNotificationsRequested()
    }
}
