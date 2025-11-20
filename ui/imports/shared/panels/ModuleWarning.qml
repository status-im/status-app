import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Core.Utils as SQUtils

import utils

Item {
    id: root

    enum Type {
        Danger,
        Warning,
        Success
    }

    property bool active: false
    property int type: ModuleWarning.Danger
    property int progressValue: -1 // 0..100, -1 not visible
    property string text: ""
    property alias buttonText: button.text
    property alias closeBtnVisible: closeImg.visible
    property string iconName
    property bool delay: true

    // extra margin that can be used to avoid overlapping with window buttons
    property int extraInnerLeftMargin: Qt.platform.os === SQUtils.Utils.mac ? 60 : 0

    signal clicked()
    signal closeClicked()
    signal showStarted()
    signal showFinished()
    signal hideStarted()
    signal hideFinished()

    function show() {
        hideTimer.stop()
        active = true;
    }

    function showFor(duration = 5000) {
        show();
        hide(duration);
    }

    function hide(timeout = 0) {
        hideTimer.interval = timeout
        hideTimer.start()
    }

    function close() {
        root.closeClicked()
    }

    signal linkActivated(string link)

    onActiveChanged: {
        if (root.active) {
            if (root.delay)
                showTimer.start()
            else
                showAnimation.start()
        }
    }

    NumberAnimation {
        id: showAnimation
        target: root
        running: (root.active && !root.delay)
        property: "implicitHeight"
        from: 0
        to: 32
        duration: ThemeUtils.AnimationDuration.Slow
        easing.type: Easing.OutCubic
        alwaysRunToEnd: true
        onStarted: {
            root.visible = true;
            root.showStarted()
        }
        onFinished: {
            root.showFinished()
        }
    }

    NumberAnimation {
        id: hideAnimation
        running: !root.active
        target: root
        property: "implicitHeight"
        from: 32
        to: 0
        duration: ThemeUtils.AnimationDuration.Slow
        easing.type: Easing.OutCubic
        onStarted: {
            root.hideStarted()
            root.visible = false;
        }
        onFinished: {
            root.hideFinished()
        }
    }

    Timer {
        id: showTimer
        interval: 3000
        onTriggered: {
            if (root.active) {
                showAnimation.start();
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 3000
        onTriggered: {
            root.active = false
        }
    }

    Rectangle {
        id: content
        anchors.fill: parent

        readonly property color baseColor: {
            switch (root.type) {
            case ModuleWarning.Danger: return Theme.palette.dangerColor1
            case ModuleWarning.Success: return Theme.palette.successColor1
            case ModuleWarning.Warning: return Theme.palette.warningColor1
            default: return Theme.palette.baseColor1
            }
        }

        color: baseColor

        Behavior on color {
            ColorAnimation {
                duration: ThemeUtils.AnimationDuration.Fast
            }
        }

        RowLayout {
            id: layout

            spacing: Theme.halfPadding
            anchors.fill: parent
            anchors.leftMargin: Theme.halfPadding + root.extraInnerLeftMargin
            anchors.rightMargin: Theme.halfPadding

            Item {
                Layout.fillWidth: true
                Layout.horizontalStretchFactor: 1
            }

            StatusRoundIcon {
                Layout.preferredHeight: 16
                Layout.preferredWidth: 16

                visible: !!root.iconName
                asset.name: root.iconName
                asset.bgColor: Theme.palette.indirectColor1
                asset.color: content.baseColor
            }

            StatusBaseText {
                Layout.fillWidth: true
                Layout.horizontalStretchFactor: 0

                objectName: "bannerText"

                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                text: root.text
                font.pixelSize: Theme.additionalTextSize
                font.weight: Font.Medium
                color: Theme.palette.indirectColor1
                linkColor: color
                onLinkActivated: (link) => root.linkActivated(link)
                HoverHandler {
                    cursorShape: hovered && parent.hoveredLink ? Qt.PointingHandCursor : undefined
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.horizontalStretchFactor: 1
            }

            StatusBaseText {
                text: qsTr("%1%").arg(progressBar.value)
                visible: progressBar.visible
                font.pixelSize: Theme.tertiaryTextFontSize
                verticalAlignment: Text.AlignVCenter
                color: StatusColors.white
            }

            ProgressBar {
                id: progressBar
                from: 0
                to: 100
                visible: root.progressValue > -1
                value: root.progressValue
                background: Rectangle {
                    implicitWidth: 64
                    implicitHeight: 8
                    radius: 8
                    color: "transparent"
                    border.width: 1
                    border.color: StatusColors.white
                }
                contentItem: Rectangle {
                    width: progressBar.width*progressBar.position
                    implicitHeight: 8
                    radius: 8
                    color: StatusColors.white
                }
            }

            Button {
                id: button
                objectName: "actionButton"
                visible: !!text
                focusPolicy: Qt.NoFocus
                onClicked: {
                    root.clicked()
                }
                contentItem: StatusBaseText {
                    text: button.text
                    font.pixelSize: Theme.additionalTextSize
                    font.weight: Font.Medium
                    font.family: Fonts.baseFont.family
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: Theme.palette.indirectColor1
                }
                background: Rectangle {
                    radius: 4
                    border.width: 1
                    border.color: Theme.palette.indirectColor3
                    color: StatusColors.getColor("white", button.hovered ? 0.4 : 0.1)
                }
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }

            StatusIcon {
                id: closeImg
                objectName: "closeButton"
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                icon: "close-circle"
                color: Theme.palette.indirectColor1
                opacity: closeButtonMouseArea.containsMouse ? 1 : 0.7

                StatusMouseArea {
                    id: closeButtonMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.closeClicked()
                    }
                }
            }
        }
    }

    // divider
    Rectangle {
        anchors.bottom: parent.bottom
        width: root.width
        height: 1
        color: Theme.palette.background
    }
}
