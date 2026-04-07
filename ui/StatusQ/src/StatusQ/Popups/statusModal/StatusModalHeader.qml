pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Popups

Rectangle {
    id: statusModalHeader

    property alias title: imageWithTitle.title
    property alias subTitle: imageWithTitle.subTitle
    property int titleElide
    property int subTitleElide
    property alias actionButton: actionButtonLoader.sourceComponent

    property alias asset: imageWithTitle.asset
    property bool editable: false
    property alias headerImageEditable: imageWithTitle.headerImageEditable
    property bool hasCloseButton: true
    property Component popupMenu

    signal editButtonClicked
    signal headerImageClicked
    signal close

    implicitHeight: visible? Math.max(closeButton.height, imageWithTitle.implicitHeight) + 32 : 0
    implicitWidth: 480

    radius: 16

    color: Theme.palette.statusModal.backgroundColor

    onPopupMenuChanged: {
        if (!!popupMenu) {
            popupMenuSlot.sourceComponent = popupMenu
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.radius
        color: parent.color

        StatusModalDivider {
            anchors.bottom: parent.bottom
            width: parent.width
        }
    }

    StatusImageWithTitle {
        id: imageWithTitle
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: actionButtonLoader.left
        anchors.leftMargin: 16

        editable: statusModalHeader.editable
        titleElide: statusModalHeader.titleElide
        subTitleElide: statusModalHeader.subTitleElide
        onHeaderImageClicked: statusModalHeader.headerImageClicked()
        onEditButtonClicked: statusModalHeader.editButtonClicked()
    }

    StatusMouseArea {
        anchors.fill: imageWithTitle
        visible: !!statusModalHeader.popupMenu
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            popupMenuSlot.item.popup(imageWithTitle.x, imageWithTitle.y + imageWithTitle.height + 8)
        }
    }

    Loader {
        id: actionButtonLoader
        objectName: "actionButtonloader"
        anchors.right: closeButton.visible ? closeButton.left : parent.right
        anchors.rightMargin: 8
        anchors.top: parent.top
        anchors.topMargin: 16
    }

    StatusFlatRoundButton {
        id: closeButton
        objectName: "headerCloseButton"
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.topMargin: 16
        width: 32
        height: 32
        type: StatusFlatRoundButton.Type.Secondary
        icon.name: "close"
        icon.color: Theme.palette.directColor1
        icon.width: 24
        icon.height: 24
        visible: statusModalHeader.hasCloseButton

        onClicked: statusModalHeader.close()
    }

    Loader {
        id: popupMenuSlot
        active: !!statusModalHeader.popupMenu
    }
}
