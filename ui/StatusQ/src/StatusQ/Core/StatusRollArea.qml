import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Popups
import StatusQ.Controls

Control {
    id: root

    property alias content: contentLoader.sourceComponent
    property color gradientColor: Theme.palette.statusAppLayout.backgroundColor
    property bool showIcon: true

    contentItem: StatusScrollView {
        id: roll

        padding: 0
        contentWidth: contentLoader.width

        StatusScrollBar.horizontal.policy: StatusScrollBar.AlwaysOff

        Loader {
            id: contentLoader
        }
    }

    StatusNavigationButton {
        anchors.left: parent.left
        height: parent.height
        visible: roll.flickable.contentX > 0
        gradientColor: root.gradientColor
        showIcon: root.showIcon

        onClicked: roll.flickable.flick(roll.width, 0)
    }

    StatusNavigationButton {
        anchors.right: parent.right
        height: parent.height
        visible: roll.flickable.contentX + roll.width < roll.contentWidth
        gradientColor: root.gradientColor
        navigateForward: true
        showIcon: root.showIcon

        onClicked: roll.flickable.flick(-roll.width, 0)
    }
}
