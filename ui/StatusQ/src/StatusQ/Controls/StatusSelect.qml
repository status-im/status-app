pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups

Item {
    id: root

    enum MenuAlignment {
        Left,
        Right,
        Center
    }

    property string label: ""
    readonly property bool hasLabel: label !== ""
    property color bgColor: Theme.palette.baseColor2
    readonly property int labelMargin: 7
    property var model
    property alias selectMenu: selectMenu
    property alias menuDelegate: menuInstantiator.delegate
    property color bgColorHover: bgColor
    // TODO: Fix the indirect handling of children
    property alias selectedItemComponent: selectedItemContainer.children
    property bool caretVisible: true
    property int caretRightMargin: 16
    property alias select: inputRectangle
    property int menuAlignment: StatusSelect.MenuAlignment.Right
    property Item zeroItemsView: Item {}
    property string validationError: ""
    property alias validationErrorAlignment: validationErrorText.horizontalAlignment
    property int validationErrorTopMargin: 11

    implicitWidth: 448

    implicitHeight: inputRectangle.height +
                    (hasLabel ? inputLabel.height + labelMargin : 0) +
                    (!!validationError ? (validationErrorText.height + validationErrorTopMargin) : 0)

    StatusBaseText {
        id: inputLabel
        visible: hasLabel
        text: root.label
        anchors.left: parent.left
        anchors.leftMargin: 0
        anchors.top: parent.top
        anchors.topMargin: 0
        font.pixelSize: Theme.primaryTextFontSize
        color: root.enabled ? Theme.palette.directColor1 : Theme.palette.baseColor1
    }

    Rectangle {
        id: inputRectangle
        height: Math.max(56, selectedItemContainer.implicitHeight)
        color: mouseArea.containsMouse ? bgColorHover : bgColor
        radius: 8
        anchors.top: root.hasLabel ? inputLabel.bottom : parent.top
        anchors.topMargin: root.hasLabel ? root.labelMargin : 0
        anchors.right: parent.right
        anchors.left: parent.left
        border.width: !!validationError ? 1 : 0
        border.color: Theme.palette.dangerColor1

        GridLayout {
            id: selectedItemContainer
            anchors.fill: parent
        }

        StatusIcon {
            id: caret
            anchors.right: parent.right
            anchors.rightMargin: caretRightMargin
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24
            icon: "chevron-down"
            color: Theme.palette.baseColor1
            visible: caretVisible
        }
    }

    Rectangle {
        width: selectMenu.width
        height: selectMenu.height
        x: selectMenu.x
        y: selectMenu.y
        visible: selectMenu.opened
        color: Theme.palette.statusSelect.menuItemBackgroundColor
        radius: 8
        border.color: Theme.palette.baseColor2
        layer.enabled: true
        layer.effect: DropShadow {
            verticalOffset: 3
            radius: 8
            samples: 15
            fast: true
            cached: true
            color: Theme.palette.dropShadow
        }
    }

    StatusMenu {
        id: selectMenu
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        width: parent.width

        StatusMenuInstantiator {
            id: menuInstantiator

            property int zeroItemsViewHeight

            menu: selectMenu
            model: root.model

            onObjectAdded: {
                root.zeroItemsView.visible = false
                root.zeroItemsView.height = 0
            }

            onObjectRemoved: {
                if (count === 0) {
                    root.zeroItemsView.visible = true
                    root.zeroItemsView.height = zeroItemsViewHeight
                }
            }

            Component.onCompleted: {
                zeroItemsViewHeight = root.zeroItemsView.height
                root.zeroItemsView.visible = count === 0
                root.zeroItemsView.height = count !== 0 ? 0 : root.zeroItemsView.height
                selectMenu.insertItem(0, root.zeroItemsView)
            }
        }
    }

    StatusBaseText {
        id: validationErrorText
        visible: !!validationError
        text: validationError
        anchors.top: inputRectangle.bottom
        anchors.topMargin: validationErrorTopMargin
        anchors.right: parent.right
        anchors.left: parent.left
        font.pixelSize: Theme.tertiaryTextFontSize
        height: visible ? implicitHeight : 0
        color: Theme.palette.dangerColor1
        horizontalAlignment: TextEdit.AlignRight
        wrapMode: Text.WordWrap
    }

    StatusMouseArea {
        id: mouseArea
        anchors.fill: inputRectangle
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: {
            if (selectMenu.opened) {
                selectMenu.close()
            } else {
                const rightOffset = inputRectangle.width - selectMenu.width
                let offset = rightOffset
                switch (root.menuAlignment) {
                    case StatusSelect.MenuAlignment.Left:
                        offset = 0
                        break
                    case StatusSelect.MenuAlignment.Right:
                        offset = rightOffset
                        break
                    case StatusSelect.MenuAlignment.Center:
                        offset = rightOffset / 2
                }
                selectMenu.popup(inputRectangle.x + offset, inputRectangle.y + inputRectangle.height + 8)
            }
        }
    }
}

