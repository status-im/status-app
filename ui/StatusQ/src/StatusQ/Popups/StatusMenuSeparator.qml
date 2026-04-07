pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal

import StatusQ.Core.Theme

MenuSeparator {
    height: visible && enabled ? implicitHeight : 0
    background: null
    contentItem: Rectangle {
        implicitWidth: 176
        implicitHeight: 1
        color: Theme.palette.statusMenu.separatorColor
    }
}
