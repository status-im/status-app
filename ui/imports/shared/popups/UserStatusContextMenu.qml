import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups
import StatusQ.Core.Utils as SQUtils

import shared.controls
import shared.controls.chat.menuItems
import utils

StatusDropdown {
    id: root

    required property string compressedPubKey
    required property var emojiHash
    required property string name
    required property string headerIcon
    required property int colorId
    required property bool usesDefaultName
    required property string bio

    property int currentUserStatus: Constants.currentUserStatus.unknown

    signal viewProfileRequested
    signal copyLinkRequested
    signal shareOwnProfileRequested
    signal setCurrentUserStatusRequested(int status)

    implicitWidth: 400
    padding: 0
    bottomPadding: root.bottomSheet ? 0 : Theme.halfPadding

    contentItem: ColumnLayout {
        spacing: 0
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.defaultPadding
            Layout.bottomMargin: Theme.halfPadding
            spacing: Theme.halfPadding

            StatusUserImage {
                Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                name: root.name
                usesDefaultName: root.usesDefaultName
                image: root.headerIcon
                userColor: Utils.colorForColorId(Theme.palette, root.colorId)
                interactive: false
                onlineStatus: root.currentUserStatus
                imageWidth: 60
                imageHeight: imageWidth
            }
            StatusBaseText {
                Layout.fillWidth: true
                font.bold: true
                font.pixelSize: Theme.fontSize(20)
                elide: Text.ElideRight
                text: SQUtils.Emoji.parse(root.name, SQUtils.Emoji.size.middle)
            }

            RowLayout {
                Layout.fillWidth: true
                StatusBaseText {
                    color: Theme.palette.baseColor1
                    text: Utils.getElidedPk(root.compressedPubKey)
                    HoverHandler {
                        id: keyHoverHandler
                    }
                    StatusToolTip {
                        text: root.compressedPubKey
                        visible: keyHoverHandler.hovered
                    }
                }
                CopyButton {
                    Layout.leftMargin: -4
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    textToCopy: root.compressedPubKey
                    StatusToolTip {
                        text: qsTr("Copy Chat Key")
                        visible: parent.hovered
                    }
                }
            }

            StatusBaseText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                maximumLineCount: 1
                text: root.bio
            }

            EmojiHash {
                Layout.fillWidth: true
                emojiHash: root.emojiHash
                oneRow: true
            }
        }

        StatusMenuSeparator {
            Layout.fillWidth: true
        }

        ActionWrapper {
            action: ViewProfileMenuItem {
                objectName: "userStatusViewMyProfileAction"
                onTriggered: {
                    root.viewProfileRequested()
                    root.close()
                }
            }
        }

        ActionWrapper {
            visible: !SQUtils.Utils.isMobile
            action: StatusAction {
                objectName: "userStatusCopyLinkAction"
                text: qsTr("Copy link to profile")
                icon.name: "copy"
                onTriggered: {
                    root.copyLinkRequested()
                    root.close()
                }
            }
        }

        ActionWrapper {
            visible: SQUtils.Utils.isMobile
            action: StatusAction {
                objectName: "userStatusShareProfileAction"
                text: qsTr("Invite contacts")
                icon.name: "add-contact"
                onTriggered: {
                    root.shareOwnProfileRequested()
                    root.close()
                }
            }
        }

        StatusMenuSeparator {
            Layout.fillWidth: true
        }

        ActionWrapper {
            font.bold: checked
            action: OnlineStatusAction {
                objectName: "userStatusMenuAlwaysOnlineAction"
                userStatus: Constants.currentUserStatus.alwaysOnline
                text: qsTr("Always online")
                icon.name: "statuses/online"
            }
        }

        ActionWrapper {
            font.bold: checked
            action: OnlineStatusAction {
                objectName: "userStatusMenuInactiveAction"
                userStatus: Constants.currentUserStatus.inactive
                text: qsTr("Inactive")
                icon.name: "statuses/inactive"
            }
        }

        ActionWrapper {
            font.bold: checked
            action: OnlineStatusAction {
                objectName: "userStatusMenuAutomaticAction"
                userStatus: Constants.currentUserStatus.automatic
                text: qsTr("Set status automatically")
                icon.name: "statuses/automatic"
            }
        }
    }

    component ActionWrapper: StatusMenuItem {
        Layout.fillWidth: true
        horizontalPadding: Theme.defaultSmallPadding
    }

    component OnlineStatusAction: StatusAction {
        required property int userStatus
        icon.color: "transparent"
        icon.width: 12
        icon.height: 12
        checked: userStatus === root.currentUserStatus
        onTriggered: {
            root.setCurrentUserStatusRequested(userStatus)
            root.close()
        }
    }
}
