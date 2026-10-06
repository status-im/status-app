import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Theme

import utils
import shared

Item {
    id: root

    property int mentionsCount
    property int recentMessagesCount

    property alias recentMessagesButtonVisible: recentMessagesButton.visible

    signal mentionsButtonClicked
    signal recentMessagesButtonClicked

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    QtObject {
        id: d

        function limitNumberTo99(number) {
            return number > 99 ? qsTr("99+") : number
        }
    }

    component AnchorButton: StatusButton {
        id: anchorButton

        Layout.preferredHeight: 40
        spacing: 2

        verticalPadding: Theme.halfPadding
        horizontalPadding: Theme.smallPadding

        RectangularShadow {
            parent: anchorButton.background
            anchors.fill: parent
            z: -1
            radius: anchorButton.radius
            blur: 8
            color: StatusColors.alphaColor(Theme.palette.directColor1, 0.16)
        }
    }

    RowLayout {
        id: layout

        anchors.fill: parent

        spacing: Theme.smallPadding

        AnchorButton {
            visible: root.mentionsCount > 0
            text: d.limitNumberTo99(root.mentionsCount)
            type: StatusBaseButton.Type.Primary
            textColor: StatusColors.white
            icon.name: "username"

            onClicked: root.mentionsButtonClicked()
        }

        AnchorButton {
            id: recentMessagesButton

            leftPadding: text ? 8 : 2
            rightPadding: 2
            text: root.recentMessagesCount <= 0 ? "" : d.limitNumberTo99(root.recentMessagesCount)
            normalColor: Theme.palette.primaryColor2
            textColor: Theme.palette.primaryColor1
            textPosition: StatusBaseButton.TextPosition.Left
            icon.name: "arrow-down"

            onClicked: root.recentMessagesButtonClicked()
        }
    }
}
