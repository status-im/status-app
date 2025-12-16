import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme


Control {
    id: root

    property alias changeAvatarImage: switchAvatarImage.checked
    property alias changeBadgeIcon: switchBadgeIcon.checked
    property alias changeBadgeIconVisible: switchBadgeIcon.visible
    property alias density: density.value
    property alias isRoundedAvatar: roundedAvatarSwitch.checked
    property alias showImplicitSizeArea: showImplicitSizeChecker.checked
    property alias includeBadgeInImplicit: includeBadgeInImplicit.checked
    property alias isAvatarClickable: isAvatarClickable.checked
    property alias isBadgeClickable: isBadgeClickable.checked

    property bool  isFullContentAvailable: true

    background: Rectangle {
        color: "lightgray"
        opacity: 0.2
        radius: 8
    }

    contentItem: ColumnLayout {

        Label {
            Layout.topMargin: Theme.padding
            Layout.leftMargin: Theme.padding
            Layout.bottomMargin: Theme.padding
            text: "AVATAR EDITOR"
            font.weight: Font.Bold
        }

        Switch {
            id: switchAvatarImage
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            text: "Change avatar image"
        }

        Switch {
            id: switchBadgeIcon
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            text: "Change badge icon"
        }

        Label {
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            text: "Density"
            visible: root.isFullContentAvailable
        }

        Slider {
            id: density
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            Layout.fillWidth: true
            value: 1
            from: 1
            to: 3
            visible: root.isFullContentAvailable
        }

        Switch {
            id: roundedAvatarSwitch
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            text: "Rounded avatar?"
            checked: true
        }

        CheckBox {
            id: showImplicitSizeChecker
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            text: "Show Implicit Size Area"
            visible: root.isFullContentAvailable
        }

        Switch {
            id: includeBadgeInImplicit
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            text: "Include Badge In Implicit Size?"
            checked: true
            visible: root.isFullContentAvailable
        }

        CheckBox {
            id: isAvatarClickable
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            text: "Is Avatar Clickable?"
            visible: root.isFullContentAvailable
        }

        CheckBox {
            id: isBadgeClickable
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            Layout.bottomMargin: Theme.padding
            text: "Is Badge Clickable?"
            visible: root.isFullContentAvailable
        }
    }
}

