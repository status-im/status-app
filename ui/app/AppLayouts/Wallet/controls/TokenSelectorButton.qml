import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Components.private
import StatusQ.Core
import StatusQ.Core.Theme

import utils

Control {
    id: root

    property bool selected
    property bool forceHovered

    property string text: qsTr("Select token")

    property string name
    property url icon
    /** optional network badge; when empty the button keeps its plain look (e.g. in Send) **/
    property url networkIcon

    readonly property bool showChip: root.selected && !!root.networkIcon.toString()

    /** Sets size of the Token Selector Button **/
    property int size: TokenSelectorButton.Size.Normal

    signal clicked

    Accessible.role: Accessible.Button
    Accessible.name: root.selected ? root.name : root.text
    Accessible.onPressAction: root.clicked()

    enum Size {
        Small,
        Normal
    }

    padding: root.selected ? (root.showChip ? 8 : 0) : 10

    background: StatusComboboxBackground {
        border.width: 0
        color: {
            if (root.selected)
                return root.showChip ? Theme.palette.baseColor4 : "transparent"

            return root.hovered || root.forceHovered
                    ? Theme.palette.primaryColor2
                    : Theme.palette.primaryColor3
        }
    }

    contentItem: Loader {
        sourceComponent: root.selected ? selectedContent : notSelectedContent
    }

    Component {
        id: notSelectedContent

        RowLayout {
            objectName: "notSelectedContent"

            spacing: 10

            StatusBaseText {
                objectName: "tokenSelectorContentItemText"
                font.pixelSize: root.font.pixelSize
                font.weight: Font.Medium
                color: Theme.palette.primaryColor1
                text: root.text
            }

            StatusComboboxIndicator {
                color: Theme.palette.primaryColor1
            }
        }
    }

    Component {
        id: selectedContent

        RowLayout {
            objectName: "selectedContent"

            spacing: Theme.halfPadding

            TokenIconWithNetworkBadge {
                id: tokenSelectorIcon
                objectName: "tokenSelectorIcon"

                readonly property int iconSize: 24

                Layout.preferredWidth: iconSize
                Layout.preferredHeight: iconSize
                // Sized here, where the render size is known (ADR-0006). Non-CDN
                // urls — asset logos, the local media server — pass through
                // untouched.
                image.source: Utils.resizedMediaSource(root.icon, iconSize)
                networkIcon: root.showChip ? root.networkIcon : ""
                badgeColor: Theme.palette.baseColor4
                badgeSize: 14
                badgeRadius: 4
                badgeIconSize: 11
                badgeIconRadius: 3
            }

            StatusBaseText {
                Layout.fillWidth: true

                objectName: "tokenSelectorContentItemText"
                font.pixelSize: root.size === TokenSelectorButton.Size.Normal ? 28 : 22
                lineHeightMode: Text.FixedHeight
                lineHeight: root.size === TokenSelectorButton.Size.Normal ? 38 : 30
                color: root.hovered ? Theme.palette.hoverColor(Theme.palette.primaryColor1) : Theme.palette.primaryColor1

                elide: Text.ElideRight
                text: root.name
            }

            StatusComboboxIndicator {
                id: comboboxIndicator

                color: Theme.palette.primaryColor1
            }
        }
    }

    StatusMouseArea {
        cursorShape: root.enabled ? Qt.PointingHandCursor : undefined
        anchors.fill: parent

        onClicked: {
            root.clicked()
        }
    }
}
