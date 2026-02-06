import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Components

Item {
    id: root
    Accessible.role: Accessible.Group
    Accessible.name: Utils.formatAccessibleName("", root.objectName)

    property StatusMessageDetails replyDetails
    property bool profileClickable: true

    signal replyProfileClicked(var sender, var mouse)
    signal messageClicked(var mouse)

    implicitHeight: layout.implicitHeight
    implicitWidth: layout.implicitWidth

    RowLayout {
        id: layout

        anchors.fill: parent
        anchors.rightMargin: 16
        spacing: 8

        Shape {
            id: replyCorner
            objectName: "statusMessageReplyCorner"
            Layout.alignment: Qt.AlignTop
            Layout.leftMargin: 35
            Layout.topMargin: profileImage.height/2
            Layout.preferredWidth: 20
            Layout.preferredHeight: messageLayout.height - replyCorner.Layout.topMargin
            asynchronous: true
            antialiasing: true

            ShapePath {
                strokeColor: {
                    const base = root.Theme.palette.baseColor1
                    return Qt.hsla(base.hslHue,
                                   base.hslSaturation,
                                   base.hslLightness, 0.4)
                }
                strokeWidth: 3
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: 20
                startY: 0
                PathLine { x: 10; y: 0 }
                PathArc {
                    x: 0; y: 10
                    radiusX: 13
                    radiusY: 13
                    direction: PathArc.Counterclockwise
                }
                PathLine { x: 0; y: messageLayout.height}
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop

            implicitHeight: messageLayout.implicitHeight
            implicitWidth: messageLayout.implicitWidth

            ColumnLayout {
                id: messageLayout
                anchors.fill: parent

                RowLayout {
                    Layout.fillWidth: true

                    StatusSmartIdenticon {
                        id: profileImage
                        Layout.alignment: Qt.AlignTop
                        name: replyDetails.sender.displayName
                        asset: replyDetails.sender.profileImage.assetSettings
                        StatusMouseArea {
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            anchors.fill: parent
                            enabled: root.profileClickable
                            onClicked: root.replyProfileClicked(this, mouse)
                        }
                    }
                    StatusBaseText {
                        Layout.alignment: Qt.AlignVCenter
                        color: Theme.palette.baseColor1
                        font.pixelSize: Theme.secondaryTextFontSize
                        font.weight: Font.Medium
                        text: replyDetails.amISender ? qsTr("You") : replyDetails.sender.displayName
                        font.underline: mouseArea.containsMouse

                        StatusMouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            enabled: root.profileClickable
                            hoverEnabled: true
                            onClicked: {
                                root.replyProfileClicked(this, mouse)
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: messageContentsLayout.implicitHeight

                    ColumnLayout {
                        id: messageContentsLayout
                        anchors.fill: parent

                        Loader {
                            Layout.fillWidth: true
                            active: !!replyDetails.messageText && replyDetails.contentType !== StatusMessage.ContentType.Sticker
                            visible: active
                            sourceComponent: StatusTextMessage {
                                objectName: "StatusMessage_replyDetails_textMessage"
                                textField.font.pixelSize: Theme.secondaryTextFontSize
                                textField.color: Theme.palette.baseColor1
                                allowShowMore: false
                                stripHtmlTags: true
                                convertToSingleLine: true
                                messageDetails: root.replyDetails
                            }
                        }

                        Loader {
                            Layout.fillWidth: true
                            active: replyDetails.contentType === StatusMessage.ContentType.Image
                            visible: active
                            sourceComponent: StatusMessageImageAlbum {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 56

                                album: replyDetails.albumCount > 0 ? replyDetails.album : [replyDetails.messageContent]
                                albumCount: replyDetails.albumCount > 0 ? replyDetails.albumCount : 1
                                imageWidth: 56
                                loadingComponentHeight: 56
                                shapeType: StatusImageMessage.ShapeType.ROUNDED
                            }
                        }

                        StatusSticker {
                            active: replyDetails.contentType === StatusMessage.ContentType.Sticker
                            visible: active
                            asset.width: 48
                            asset.height: 48
                            asset.name: replyDetails.messageContent
                            asset.isImage: true
                        }
                    }

                    StatusMouseArea {
                        anchors.fill: parent
                        enabled: !root.replyDetails.messageDeleted && root.replyDetails.sender.id
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            root.messageClicked(mouse)
                        }
                    }
                }
            }
        }
    }
}

