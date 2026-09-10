import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Popups.Dialog
import StatusQ.Core.Utils as StatusQUtils

import shared.controls
import shared.controls.chat
import utils

// Adaptive replacement for CommonContactDialog. TODO: migrate the remaining
// CommonContactDialog-derived popups to this component and remove the legacy dialog.
StatusAdaptiveDialog {
    id: root

    // Raw contact public key used to resolve the contact identity.
    required property string publicKey
    // Display-ready compressed public key. Resolve it outside this component.
    required property string compressedPublicKey
    // Display-ready emoji hash. Resolve it outside this component.
    required property string emojiHash
    // Contact profile details used by the header area.
    required property var contactDetails
    // Whether the contact profile details are currently being refreshed.
    property bool loadingContactDetails

    // Body content rendered below the contact header.
    property Component bodyComponent

    // Primary display name resolved from the contact details.
    readonly property string mainDisplayName: StatusQUtils.Emoji.parse(
                                                  ProfileUtils.displayName(contactDetails.localNickname, contactDetails.name,
                                                                           contactDetails.displayName, contactDetails.alias))
    // Secondary display name shown when a local nickname is present.
    readonly property string optionalDisplayName: StatusQUtils.Emoji.parse(
                                                      ProfileUtils.displayName("", contactDetails.name, contactDetails.displayName, contactDetails.alias))

    contentComponent: ColumnLayout {
        id: contentLayout

        spacing: Theme.padding

        RowLayout {
            Layout.fillWidth: true
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
                            text: root.compressedPublicKey
                            visible: keyHoverHandler.hovered
                        }
                    }
                }

                EmojiHash {
                    Layout.topMargin: 4
                    emojiHash: root.emojiHash
                    oneRow: true
                }
            }
        }

        StatusDialogDivider {
            Layout.fillWidth: true
        }

        Loader {
            Layout.fillWidth: true
            sourceComponent: root.bodyComponent
        }
    }
}
