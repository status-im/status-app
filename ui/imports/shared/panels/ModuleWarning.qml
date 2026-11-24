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
    property bool closeBtnVisible: true
    property string iconName
    property bool delay: true

    // × collapses instead of closing: always shown, never emits closeClicked
    property bool collapsible: false
    readonly property alias collapsed: d.collapsed
    property string collapsedIconName: "caution"

    // replaces text and icon; centred, clamped between the left margin and the right-hand controls
    property Component actions

    // unset: the compact button hangs below this warning, where later siblings in a layout can cover it
    property Item collapsedButtonParent

    // extra margin that can be used to avoid overlapping with window buttons
    property int extraInnerLeftMargin: SQUtils.Utils.isMacOS ? 60 : 0

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

    function collapse() {
        // still waiting for the delayed show
        const showing = showAnimation.running || expandAnimation.running || root.implicitHeight > 0
        if (!root.collapsible || !root.active || d.collapsed || !showing)
            return

        showTimer.stop()
        if (showAnimation.running) {
            // collapse from the current height, not from the end of the show
            showAnimation.alwaysRunToEnd = false
            showAnimation.stop()
            showAnimation.alwaysRunToEnd = true
            root.showFinished()
        }
        expandAnimation.stop()
        root.visible = true
        d.collapsed = true
        collapseAnimation.start()
    }

    function expand() {
        if (!d.collapsed)
            return

        collapseAnimation.stop()
        d.collapsed = false
        expandAnimation.start()
    }

    signal linkActivated(string link)

    onActiveChanged: {
        collapseAnimation.stop()
        expandAnimation.stop()
        d.collapsed = false
        d.focusExpandButtonWhenShown = false

        if (root.active) {
            if (root.delay)
                showTimer.start()
            else
                showAnimation.start()
        }
    }

    QtObject {
        id: d

        property bool collapsed: false
        property bool focusExpandButtonWhenShown: false

        readonly property int bannerHeight: 32
        readonly property int expandButtonSize: 40
        readonly property int expandButtonTopMargin: 4

        readonly property int focusPolicy: SQUtils.Utils.isMobile ? Qt.NoFocus : Qt.TabFocus
    }

    NumberAnimation {
        id: showAnimation
        target: root
        running: (root.active && !root.delay)
        property: "implicitHeight"
        from: 0
        to: d.bannerHeight
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
        from: d.bannerHeight
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

    NumberAnimation {
        id: collapseAnimation
        target: root
        property: "implicitHeight"
        to: 0
        duration: ThemeUtils.AnimationDuration.Slow
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: expandAnimation
        target: root
        property: "implicitHeight"
        to: d.bannerHeight
        duration: ThemeUtils.AnimationDuration.Slow
        easing.type: Easing.OutCubic
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

        visible: !d.collapsed || collapseAnimation.running
        clip: d.collapsed || expandAnimation.running
        color: baseColor

        Behavior on color {
            ColorAnimation {
                duration: ThemeUtils.AnimationDuration.Fast
            }
        }

        Loader {
            id: actionsLoader
            objectName: "actionsLoader"

            readonly property real minX: layout.anchors.leftMargin
            readonly property real maxX: {
                const rightControls = [progressText, progressBar, button, closeButton]
                    .filter(control => control.visible)
                const rightEdge = rightControls.length
                    ? layout.x + Math.min(...rightControls.map(control => control.x)) - layout.spacing
                    : content.width - layout.anchors.rightMargin
                return rightEdge - width
            }

            x: Math.max(minX, Math.min((content.width - width) / 2, maxX))
            anchors.verticalCenter: parent.verticalCenter

            sourceComponent: root.actions
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

                visible: !!root.iconName && !root.actions
                asset.name: root.iconName
                asset.bgColor: Theme.palette.indirectColor1
                asset.color: content.baseColor
            }

            StatusBaseText {
                Layout.fillWidth: true
                Layout.horizontalStretchFactor: 0

                objectName: "bannerText"

                visible: !root.actions
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
                id: progressText
                objectName: "progressText"
                text: qsTr("%1%").arg(progressBar.value)
                visible: progressBar.visible
                font.pixelSize: Theme.tertiaryTextFontSize
                verticalAlignment: Text.AlignVCenter
                color: StatusColors.white
            }

            ProgressBar {
                id: progressBar
                objectName: "progressBar"
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
                Layout.fillHeight: true
                visible: !!text
                focusPolicy: Qt.NoFocus
                onClicked: {
                    root.clicked()
                }
                contentItem: StatusBaseText {
                    text: button.text
                    font.pixelSize: Theme.additionalTextSize
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: Theme.palette.indirectColor1
                }
                background: Rectangle {
                    radius: 4
                    border.width: 1
                    border.color: Theme.palette.indirectColor3
                    color: StatusColors.alphaColor(StatusColors.white, button.hovered ? 0.4 : 0.1)
                }
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }

            AbstractButton {
                id: closeButton
                objectName: "closeButton"

                Layout.preferredWidth: 20
                Layout.preferredHeight: 20

                visible: root.collapsible || root.closeBtnVisible
                focusPolicy: d.focusPolicy

                Accessible.role: Accessible.Button
                Accessible.name: root.collapsible ? qsTr("Collapse warning") : qsTr("Close warning")

                contentItem: StatusIcon {
                    icon: "close-circle"
                    color: Theme.palette.indirectColor1
                    opacity: closeButton.hovered || closeButton.visualFocus ? 1 : 0.7
                }

                background: Rectangle {
                    radius: width / 2
                    color: "transparent"
                    border.width: closeButton.visualFocus ? 2 : 0
                    border.color: Theme.palette.indirectColor1
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                Keys.onReturnPressed: click()
                Keys.onEnterPressed: click()

                onClicked: {
                    if (!root.collapsible) {
                        root.closeClicked()
                        return
                    }

                    d.focusExpandButtonWhenShown = closeButton.activeFocus
                    root.collapse()
                }
            }
        }
    }

    // divider
    Rectangle {
        anchors.bottom: parent.bottom
        width: root.width
        height: 1
        visible: !d.collapsed
        color: Theme.palette.background
    }

    AbstractButton {
        id: expandButton
        objectName: "expandButton"

        // used by ModuleWarningStack to order its row
        readonly property Item warning: root

        parent: root.collapsedButtonParent ?? root
        x: root.collapsedButtonParent ? 0 : (root.width - width) / 2
        y: root.collapsedButtonParent ? 0 : root.height + d.expandButtonTopMargin
        width: d.expandButtonSize
        height: d.expandButtonSize

        visible: root.active && d.collapsed && !collapseAnimation.running
        focusPolicy: d.focusPolicy

        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Expand warning")
        Accessible.description: root.text.replace(/<[^>]*>/g, "")

        contentItem: Item {
            StatusIcon {
                anchors.centerIn: parent
                width: 24
                height: 24
                icon: root.collapsedIconName
                color: Theme.palette.indirectColor1
            }
        }

        background: Rectangle {
            radius: 8
            color: content.baseColor
            opacity: expandButton.hovered ? 0.9 : 1
            border.width: expandButton.visualFocus ? 2 : 0
            border.color: Theme.palette.indirectColor1
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        Keys.onReturnPressed: click()
        Keys.onEnterPressed: click()

        onVisibleChanged: {
            if (visible && d.focusExpandButtonWhenShown)
                forceActiveFocus()
            d.focusExpandButtonWhenShown = false
        }

        onClicked: {
            const hadFocus = expandButton.activeFocus
            root.expand()
            if (hadFocus)
                closeButton.forceActiveFocus()
        }
    }
}
