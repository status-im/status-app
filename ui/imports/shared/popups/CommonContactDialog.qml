import QtQuick
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Popups.Dialog
import StatusQ.Core.Utils as StatusQUtils

import shared.controls
import shared.controls.chat
import shared.stores
import utils

StatusDialog {
    id: root

    required property UtilsStore utilsStore

    required property string publicKey
    required property var contactDetails
    property bool loadingContactDetails

    default property alias content: contentLayout.children

    property ObjectModel rightButtons

    readonly property string mainDisplayName: StatusQUtils.Emoji.parse(
                                                  ProfileUtils.displayName(contactDetails.localNickname, contactDetails.name,
                                                                           contactDetails.displayName, contactDetails.alias))
    readonly property string optionalDisplayName: StatusQUtils.Emoji.parse(
                                                      ProfileUtils.displayName("", contactDetails.name, contactDetails.displayName, contactDetails.alias))

    width: Math.max(implicitWidth, 480)
    horizontalPadding: 0
    topPadding: 20
    bottomPadding: 0

    contentItem: ColumnLayout {
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            spacing: Theme.padding

            StatusUserImage {
                name: root.mainDisplayName
                usesDefaultName: contactDetails.usesDefaultName
                userColor: Utils.colorForColorId(Theme.palette, contactDetails.colorId)
                image: contactDetails.largeImage
                interactive: false
                imageWidth: 60
                imageHeight: 60
                onlineStatus: contactDetails.onlineStatus
                loading: root.loadingContactDetails
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Item {
                    id: contactRow
                    Layout.fillWidth: true
                    Layout.preferredHeight: childrenRect.height
                    StatusBaseText {
                        id: contactName
                        anchors.left: parent.left
                        width: Math.min(implicitWidth, contactRow.width - verificationIcons.width - verificationIcons.anchors.leftMargin)
                        font.bold: true
                        font.pixelSize: Theme.secondaryAdditionalTextSize
                        elide: Text.ElideRight
                        text: root.mainDisplayName
                    }
                    StatusContactVerificationIcons {
                        id: verificationIcons
                        anchors.left: contactName.right
                        anchors.leftMargin: Theme.halfPadding
                        anchors.verticalCenter: contactName.verticalCenter
                        isContact: contactDetails.isContact
                        trustIndicator: contactDetails.trustStatus
                        isBlocked: contactDetails.isBlocked
                        tiny: false
                    }
                }
                RowLayout {
                    spacing: Theme.halfPadding
                    StatusBaseText {
                        id: contactSecondaryName
                        color: Theme.palette.baseColor1
                        font.pixelSize: Theme.additionalTextSize
                        text: root.optionalDisplayName
                        visible: !!contactDetails.localNickname
                    }
                    Rectangle {
                        Layout.preferredWidth: 4
                        Layout.preferredHeight: 4
                        radius: width/2
                        color: Theme.palette.baseColor1
                        visible: contactSecondaryName.visible
                    }
                    StatusBaseText {
                        color: Theme.palette.baseColor1
                        font.pixelSize: Theme.additionalTextSize
                        text: Utils.getElidedCompressedPk(root.publicKey)
                        HoverHandler {
                            id: keyHoverHandler
                        }
                        StatusToolTip {
                            text: root.utilsStore.getCompressedPk(root.publicKey)
                            visible: keyHoverHandler.hovered
                        }
                    }
                }
                EmojiHash {
                    Layout.topMargin: 4
                    emojiHash: root.utilsStore.getEmojiHash(root.publicKey)
                    oneRow: true
                }
            }
        }

        StatusDialogDivider {
            Layout.fillWidth: true
            Layout.topMargin: Theme.padding
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
        }

        StatusScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            id: scrollView

            ColumnLayout {
                width: scrollView.availableWidth
                id: contentLayout
            }
        }
    }

    footer: StatusDialogFooter {
        bottomPadding: Theme.padding + root.parent.SafeArea.margins.bottom
        rightButtons: root.rightButtons
    }
}
