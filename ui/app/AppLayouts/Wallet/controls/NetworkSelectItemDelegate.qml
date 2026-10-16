import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Theme

CheckDelegate {
    id: root

    property bool showIndicator: true
    property bool showNewIcon: false
    property bool interactive: true

    objectName: root.text
    tristate: false

    icon.height: 24
    icon.width: 24

    font.family: Fonts.baseFont.family
    font.weight: Font.Normal
    font.pixelSize: Theme.primaryTextFontSize

    padding: 8
    spacing: 12

    enabled: interactive
    hoverEnabled: enabled

    background: Rectangle {
        radius: 10
        color: {
            if (root.hovered)
                return Theme.palette.primaryColor2
            if (root.checked || root.down || root.highlighted)
                return Theme.palette.primaryColor3
            return Theme.palette.transparent
        }
    }

    contentItem: RowLayout {
        spacing: root.spacing
        StatusIcon {
            Layout.preferredWidth: root.icon.width
            Layout.preferredHeight: root.icon.height
            objectName: "statusRoundImage"
            color: root.icon.color
            source: root.icon.source
            sourceSize: Qt.size(width, height)

            Binding on icon {
                value: "network/%1".arg(root.icon.name)
                when: root.icon.name !== ""
            }
        }
        StatusBaseText {
            Layout.fillWidth: true
            text: root.text
            font: root.font
            color: root.interactive ? Theme.palette.primaryColor1 : Theme.palette.baseColor1
            elide: Text.ElideRight
        }
        Loader {
            Layout.leftMargin: -4
            active: root.showNewIcon
            visible: active
            sourceComponent: StatusNewTag {
                objectName: "networkSelectionNewIcon_" + root.text
                tooltipText: qsTr("%1 chain integrated. You can now view and swap <br>%1 assets, as well as interact with %1 dApps.").arg(root.text)
            }
        }
        Item {
            // indicator/checkmark spacer
            Layout.preferredWidth: root.indicator.width + root.spacing
        }
    }

    indicator: Item {
        width: root.icon.width
        height: root.icon.height
        visible: root.showIndicator && root.checked
        x: root.width - width - root.rightPadding
        anchors.verticalCenter: parent.verticalCenter
        StatusIcon {
            objectName: "networkSelectionCheckbox_" + root.text
            width: 12
            height: 9
            anchors.centerIn: parent
            icon: "check"
            color: Theme.palette.primaryColor1
        }
    }

    HoverHandler {
        enabled: root.hoverEnabled
        cursorShape: hovered ? Qt.PointingHandCursor : undefined
    }
}
