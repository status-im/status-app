import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups

Rectangle {
    id: root

    property list<Item> leftButtons
    property list<StatusBaseButton> rightButtons
    property bool showFooter: true

    QtObject {
        id: d

        function buttonsImplicitWidth(buttons) {
            let width = 0
            for (let idx in buttons)
                width += buttons[idx].implicitWidth

            return width + Math.max(0, buttons.length - 1) * Theme.padding
        }
    }

    radius: Theme.radius

    color: Theme.palette.statusModal.backgroundColor

    onLeftButtonsChanged: {
        for (let idx in leftButtons) {
            leftButtons[idx].parent = leftButtonsLayout
            leftButtons[idx].Layout.fillWidth
                    = Qt.binding(() => root.width < root.implicitWidth)
        }
    }

    onRightButtonsChanged: {
        for (let idx in rightButtons) {
            rightButtons[idx].parent = rightButtonsLayout
            rightButtons[idx].Layout.fillWidth
                    = Qt.binding(() => root.width < root.implicitWidth)
        }
    }

    implicitWidth: d.buttonsImplicitWidth(leftButtons)
                   + d.buttonsImplicitWidth(rightButtons)
                   + Theme.padding
                   + rootLayout.anchors.leftMargin
                   + rootLayout.anchors.rightMargin
    implicitHeight: rootLayout.implicitHeight + 30

    RowLayout {
        id: rootLayout
        spacing: 0
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.padding
        anchors.rightMargin: Theme.padding

        RowLayout {
            id: leftButtonsLayout
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            visible: root.showFooter

            spacing: Theme.padding
        }

        Item {
            Layout.fillWidth: true
            Layout.minimumWidth: Theme.padding
        }

        RowLayout {
            id: rightButtonsLayout
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            visible: root.showFooter

            spacing: Theme.padding
        }
    }

    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: parent.radius
        color: parent.color

        StatusModalDivider {
            visible: (root.leftButtons.length || root.rightButtons.length) && rootLayout.height > 1
            anchors.top: parent.top
            width: parent.width
        }
    }
}
