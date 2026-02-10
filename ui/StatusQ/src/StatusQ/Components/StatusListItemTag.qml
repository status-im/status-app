import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import StatusQ.Core
import StatusQ.Core.Theme

Control {
    id: root

    property alias titleText: titleText
    property string title: ""
    property bool tagClickable: false
    property bool closeButtonVisible: true
    property color bgColor: Theme.palette.primaryColor3
    property color bgBorderColor: "transparent"
    property int bgRadius: 15

    signal clicked(var mouse)
    signal tagClicked(var mouse)

    property StatusAssetSettings asset: StatusAssetSettings {
        height: 20
        width: 20
        rotation: 0
        isLetterIdenticon: false
        letterSize: 10
        color: root.Theme.palette.primaryColor1
        bgWidth: 15
        bgHeight: 15
        bgColor: root.Theme.palette.primaryColor3
        bgRadius: bgWidth / 2
        imgIsIdenticon: false
    }

    QtObject {
        id: d
        readonly property int commonMargin: 6
        readonly property int minHeight: 30
    }

    leftPadding: d.commonMargin
    rightPadding: d.commonMargin
    spacing: d.commonMargin
    implicitHeight: d.minHeight
    background: Rectangle {
        color: root.bgColor
        radius: root.bgRadius
        border.color: root.bgBorderColor
    }

    StatusMouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            root.tagClicked(mouse)
        }
        z: -1
    }

    contentItem: RowLayout {
        id: layout
        spacing: root.spacing

        StatusSmartIdenticon {
            id: iconOrImage
            asset: root.asset
            name: root.title
            active: root.asset.isLetterIdenticon ||
                    !!root.asset.name
        }

        StatusBaseText {
            id: titleText
            Layout.fillWidth: true
            color: Theme.palette.primaryColor1
            text: root.title
            elide: Text.ElideRight
        }

        StatusIcon {
            id: closeIcon
            color: Theme.palette.primaryColor1
            icon: "close-circle"
            visible: root.closeButtonVisible
            StatusMouseArea {
                cursorShape: Qt.PointingHandCursor
                anchors.fill: parent
                onClicked: (mouse) => {
                    root.clicked(mouse)
                }
            }
        }
    }
}
