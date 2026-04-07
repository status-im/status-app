pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

Control {
    id: root

    property alias title: titleComponent.text
    property alias text: textComponent.text
    property string icon
    property int iconType: StatusInfoBoxPanel.Type.Info
    property alias buttonText: button.text
    property bool buttonVisible: true
    property bool buttonEnabled: true

    enum Type {
        Info,
        Danger,
        Success,
        Warning
    }

    signal clicked

    verticalPadding: 32
    horizontalPadding: 16

    QtObject {
        id: d
        property color bgColor
        property color fgColor
    }

    states: [
        State {
            when: root.iconType === StatusInfoBoxPanel.Type.Info
            PropertyChanges { target: d; bgColor: Theme.palette.primaryColor3; fgColor: Theme.palette.primaryColor1 }
        },
        State {
            when: root.iconType === StatusInfoBoxPanel.Type.Danger
            PropertyChanges { target: d; bgColor: Theme.palette.dangerColor3; fgColor: Theme.palette.dangerColor1 }
        },
        State {
            when: root.iconType === StatusInfoBoxPanel.Type.Success
            PropertyChanges { target: d; bgColor: Theme.palette.successColor2; fgColor: Theme.palette.successColor1 }
        },
        State {
            when: root.iconType === StatusInfoBoxPanel.Type.Warning
            PropertyChanges { target: d; bgColor: Theme.palette.warningColor3; fgColor: Theme.palette.warningColor1 }
        }
    ]

    background: Rectangle {
        color: Theme.palette.statusListItem.backgroundColor
        radius: 16
        border.color: Theme.palette.baseColor2
    }

    contentItem: ColumnLayout {
        spacing: 16

        StatusRoundIcon {
            id: iconComponent
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            Layout.alignment: Qt.AlignCenter
            Layout.bottomMargin: 12
            visible: !!root.icon
            asset.name: root.icon
            asset.color: d.fgColor
            asset.bgColor: d.bgColor
        }

        StatusBaseText {
            id: titleComponent

            Layout.fillWidth: true

            wrapMode: Text.Wrap
            font.pixelSize: Theme.secondaryAdditionalTextSize
            font.weight: Font.Bold

            horizontalAlignment: Text.AlignHCenter
            color: Theme.palette.directColor1
        }

        StatusBaseText {
            id: textComponent

            Layout.fillWidth: true

            wrapMode: Text.Wrap
            font.pixelSize: Theme.primaryTextFontSize
            lineHeight: 1.2

            horizontalAlignment: Text.AlignHCenter
            color: Theme.palette.baseColor1
        }

        StatusButton {
            id: button

            objectName: "statusInfoBoxPanelButton"
            
            Layout.alignment: Qt.AlignHCenter

            visible: root.buttonVisible
            enabled: root.buttonEnabled

            onClicked: root.clicked()
        }
    }
}
