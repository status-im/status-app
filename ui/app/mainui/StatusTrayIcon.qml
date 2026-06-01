import QtQml
import Qt.labs.platform

import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import utils

SystemTrayIcon {
    id: root

    property bool showRedDot: false

    signal activateApp()

    visible: true

    icon.source: {
        if (Qt.platform.os === SQUtils.Utils.windows) {
            return root.showRedDot ? Assets.svg("status-logo-white-windows-with-red-dot") : Assets.svg("status-logo-white-windows")
        }
        return root.showRedDot ? Assets.svg("status-logo-white-with-red-dot") : Assets.svg("status-logo-white")
    }
    icon.mask: Qt.platform.os !== SQUtils.Utils.windows

    onMessageClicked: {
        if (Qt.platform.os === SQUtils.Utils.windows) {
            root.activateApp()
        }
    }

    menu: Menu {
        MenuItem {
            text: qsTr("Open Status")
            onTriggered: {
                root.activateApp()
            }
        }

        MenuSeparator {
        }

        MenuItem {
            text: qsTr("Quit")
            onTriggered: Qt.exit(0)
        }
    }

    onActivated: function(reason) {
        if (reason !== SystemTrayIcon.Context) {
            root.activateApp()
        }
    }
}
