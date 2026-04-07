pragma ComponentBehavior: Bound

import QtQuick

import StatusQ.Core.Theme
import StatusQ.Components.private

Rectangle {
    implicitWidth: 12
    implicitHeight: 12
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: -border.width*2
    anchors.topMargin: -border.width*2
    border.width: 2
    border.color: Theme.palette.statusBadge.borderColor
    radius: height/2
    gradient: StatusNewItemGradient {}
}
