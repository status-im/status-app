import QtQuick
import QtQuick.Controls

import utils
import shared
import shared.panels

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Components.private

Rectangle {
    id: root
    objectName: "statusChatInputReplyArea"

    implicitHeight: (root.contentType === Constants.messageContentType.imageType)
                    ? replyToUsername.height + imageThumbnail.height + Theme.padding
                    : (root.contentType === Constants.messageContentType.stickerType)
                      ? replyToUsername.height + stickerThumbnail.height + Theme.padding
                      : 50

    color: Theme.palette.baseColor3
    radius: 16
    clip: true

    Accessible.role: Accessible.Pane
    Accessible.name: root.visible ? qsTr("Replying to %1").arg(root.userName) : ""

    property string userName: ""
    property string message : ""
    property string image: ""
    property string stickerData: ""
    property string messageId: ""
    property int contentType: -1
    property var album: []
    property int albumCount: 0

    signal closeButtonClicked()

    Rectangle {
        color: parent.color
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        height: parent.height / 2
        width: 32
        radius: Theme.radius
    }

    StyledText {
        id: replyToUsername
        text: "↪ " + userName
        color: Theme.palette.textColor
        anchors.top: parent.top
        anchors.topMargin: Theme.halfPadding
        anchors.left: parent.left
        anchors.leftMargin: Theme.smallPadding
        font.pixelSize: Theme.additionalTextSize
        font.weight: Font.Medium
    }

    Rectangle {
        anchors.left: replyToUsername.left
        anchors.top: replyToUsername.bottom
        anchors.topMargin: -3
        anchors.right: parent.right
        anchors.rightMargin: Theme.padding
        anchors.bottom: parent.bottom
        clip: true
        color: StatusColors.transparent
        visible: (root.contentType !== Constants.messageContentType.imageType) && (root.contentType !== Constants.messageContentType.stickerType)

        StyledText {
            id: replyText
            text: StatusQUtils.Utils.getMessageWithStyle(
                      root.Theme.palette, StatusQUtils.Emoji.parse(StatusQUtils.Utils.linkifyAndXSS(message)), false)
            anchors.fill: parent
            elide: Text.ElideRight
            font.pixelSize: Theme.additionalTextSize
            font.weight: Font.Normal
            textFormat: Text.RichText
            color: Theme.palette.textColor
        }
    }

    StatusMessageImageAlbum {
        id: imageThumbnail
        anchors.left: replyToUsername.left
        anchors.top: replyToUsername.bottom
        anchors.topMargin: 2
        album: root.albumCount > 0 ? root.album : [root.image]
        albumCount: root.albumCount > 0 ? root.albumCount : 1
        imageWidth: 56
        loadingComponentHeight: 56
        shapeType: StatusImageMessage.ShapeType.ROUNDED
    }

    StatusSticker {
        id: stickerThumbnail
        anchors.left: replyToUsername.left
        anchors.top: replyToUsername.bottom
        anchors.topMargin: 2
        imageWidth: 64
        imageHeight: 64
        stickerData: root.stickerData
        color: StatusColors.transparent
        contentType: root.contentType
    }

    RoundButton {
        id: closeBtn
        objectName: "replyAreaCloseButton"
        implicitWidth: 20
        implicitHeight: 20
        radius: 10
        padding: 0
        anchors.top: parent.top
        anchors.topMargin: 4
        anchors.right: parent.right
        anchors.rightMargin: 4
        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Cancel reply")
        contentItem: StatusIcon {
            id: iconImg
            source: Assets.svg("close")
            color: Theme.palette.textColor
            sourceSize: Qt.size(width, height)
            width: closeBtn.width
            height: closeBtn.height
        }
        background: Rectangle {
            color: "transparent"
            width: closeBtn.width
            height: closeBtn.height
            radius: closeBtn.radius
        }
        onClicked: {
            root.userName = ""
            root.message = ""
            root.messageId = ""
            root.stickerData = ""
            root.image = ""
            root.contentType = -1
            root.closeButtonClicked()
        }
        StatusMouseArea {
            cursorShape: Qt.PointingHandCursor
            anchors.fill: parent
            onPressed: mouse.accepted = false
        }
    }

}
