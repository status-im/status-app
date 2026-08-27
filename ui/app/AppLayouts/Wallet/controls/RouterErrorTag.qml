import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components

Control {
    id: root

    property alias errorTitle: errorTitle.text
    property alias buttonText: addBalanceButton.text
    property alias errorDetails: errorDetails.text
    property alias icon: errorIcon.icon
    property bool expandable

    signal buttonClicked()

    padding: Theme.halfPadding
    leftPadding: 12

    background: Rectangle {
        radius: 8
        color: Theme.palette.dangerColor3
        border.width: 1
        border.color: Theme.palette.dangerColor2
    }

    contentItem: ColumnLayout {
        RowLayout {
            spacing: Theme.halfPadding
            StatusIcon {
                id: errorIcon

                objectName: "errorIcon"

                Layout.alignment: Qt.AlignVCenter

                icon: "warning"
                color: Theme.palette.dangerColor1
            }
            StatusBaseText {
                id: errorTitle

                objectName: "errorTitle"

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                color: Theme.palette.dangerColor1
                font.pixelSize: Theme.additionalTextSize
                elide: Text.ElideRight
            }
            StatusButton {
                id: addBalanceButton

                objectName: "addBalanceButton"

                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                size: StatusBaseButton.Size.Small
                type: StatusBaseButton.Type.Danger
                normalColor: Theme.palette.dangerColor1
                hoverColor: Theme.palette.hoverColor(normalColor)
                textColor: Theme.palette.indirectColor1

                onClicked: root.buttonClicked()

                visible: !root.expandable && !!text
            }
            StatusButton {
                id: expandButton

                objectName: "expandButton"

                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                checkable: true
                size: StatusBaseButton.Size.Small
                normalColor: StatusColors.transparent
                hoverColor: StatusColors.transparent
                textColor: Theme.palette.dangerColor1
                textHoverColor: Theme.palette.hoverColor(textColor)
                font.pixelSize: Theme.tertiaryTextFontSize
                font.weight: Font.Normal
                text: checked ? qsTr("- Hide details") : qsTr("+ Show details")

                visible: root.expandable
            }
        }
        StatusBaseText {
            id: errorDetails

            objectName: "errorDetails"

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: errorIcon.width + Theme.halfPadding

            color: Theme.palette.dangerColor1
            font.pixelSize: Theme.additionalTextSize
            wrapMode: Text.Wrap
            maximumLineCount: 5
            elide: Text.ElideRight

            visible: root.expandable ? expandButton.checked : !!text
        }
    }
}
