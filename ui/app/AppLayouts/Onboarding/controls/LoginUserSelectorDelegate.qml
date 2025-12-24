import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Popups
import StatusQ.Core.Utils as StatusQUtils

import shared.controls.chat
import utils

ItemDelegate {
    id: root

    property string label
    property int colorId
    property string image
    property bool keycardCreatedAccount
    property bool keycardLocked
    property bool keycardEnabled
    property bool isAction
    property bool managementMode

    signal deleteProfileRequested()

    verticalPadding: 12
    leftPadding: Theme.padding
    rightPadding: Theme.bigPadding
    spacing: Theme.padding

    hoverEnabled: enabled
    opacity: enabled ? 1 : ThemeUtils.disabledOpacity

    background: Rectangle {
        color: root.hovered || root.highlighted ? Theme.palette.statusSelect.menuItemHoverBackgroundColor
                                                : "transparent"
    }

    contentItem: RowLayout {
        spacing: root.spacing
        Loader {
            id: userImageOrIcon
            sourceComponent: root.isAction ? actionIcon : userImage
        }

        Component {
            id: actionIcon
            StatusRoundIcon {
                asset.name: root.image
            }
        }

        Component {
            id: userImage
            StatusUserImage {
                name:  root.label
                // TODO we should be checking if the user set a custom name
                // but it requires changing the DB which is probably not worth it
                usesDefaultName: !root.image
                image: root.image
                userColor: Utils.colorForColorId(Theme.palette, root.colorId)
                imageHeight: Constants.onboarding.userImageHeight
                imageWidth: Constants.onboarding.userImageWidth
            }
        }

        ColumnLayout {
            StatusBaseText {
                Layout.fillWidth: true
                text: StatusQUtils.Emoji.parse(root.label)
                color: root.isAction ? Theme.palette.primaryColor1 : Theme.palette.directColor1
                elide: Text.ElideRight
            }
            StatusBaseText {
                Layout.fillWidth: true
                visible: root.keycardCreatedAccount && !root.keycardEnabled
                text: qsTr("Keycard is not yet supported")
                font.pixelSize: Theme.tertiaryTextFontSize
                elide: Text.ElideRight
            }
        }

        Loader {
            id: keycardIcon
            active: root.keycardCreatedAccount
            sourceComponent: StatusIconWithTooltip {
                icon: "keycard"
                color: root.keycardLocked || !root.keycardEnabled ? Theme.palette.dangerColor1 : Theme.palette.baseColor1
                tooltipText: !root.keycardEnabled ? qsTr("Keycard is not yet supported") : ""
            }
        }

        Loader {
            active: root.managementMode
            sourceComponent: StatusFlatButton {
                objectName: "deleteProfileButton"
                size: StatusBaseButton.Size.Large
                icon.name: "delete"
                onClicked: root.deleteProfileRequested()
            }
        }
    }

    HoverHandler {
        cursorShape: root.enabled ? Qt.PointingHandCursor : undefined
    }
}
