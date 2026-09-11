import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

import Storybook

import shared.popups
import utils

SplitView {
    id: root

    orientation: Qt.Horizontal

    Logs {
        id: logs
    }

    QtObject {
        id: d

        readonly property string publicKey: "0x04d9f8b31df7b53f8ef91c0f5f85b0fbd9a96a9b7c2e4f6d8a1b3c5d7e9f102030405060708090a0b0c0d0e0f00112233445566778899aabbccddeeff"
        readonly property string compressedPublicKey: publicKey.substring(0, 10) + "..." + publicKey.substring(publicKey.length - 8)
        readonly property var emojiHash: ["👨🏻‍🍼", "🏃🏿‍♂️", "🌇", "🤶🏿", "🏮", "🤷🏻‍♂️", "🤦🏻", "📣", "🤎", "👷🏽", "😺", "🥞", "🔃", "🧝🏽‍♂️"]
        readonly property var contactDetails: ({
                "localNickname": nicknameInput.text,
                "name": "steady-signal",
                "displayName": displayNameInput.text,
                "alias": "Admirable Steel Signal",
                "usesDefaultName": false,
                "colorId": 5,
                "largeImage": "",
                "onlineStatus": 0,
                "isContact": isContactCheckBox.checked,
                "trustStatus": trustedCheckBox.checked ? Constants.trustStatus.trusted : Constants.trustStatus.unknown,
                "isBlocked": blockedCheckBox.checked
            })
    }

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        PopupBackground {
            anchors.fill: parent
        }

        Button {
            anchors.centerIn: parent
            text: "Reopen"
            onClicked: popup.open()
        }

        CommonContactAdaptiveDialog {
            id: popup

            modal: false
            title: titleInput.text
            publicKey: d.publicKey
            compressedPublicKey: d.compressedPublicKey
            emojiHash: d.emojiHash
            contactDetails: d.contactDetails

            bodyComponent: ColumnLayout {
                spacing: Theme.padding

                StatusBaseText {
                    Layout.fillWidth: true
                    text: bodyTextInput.text
                    wrapMode: Text.WordWrap
                }

                StatusInput {
                    Layout.fillWidth: true
                    label: "Message"
                    placeholderText: "Write a message..."
                    input.multiline: true
                    minimumHeight: 152
                    maximumHeight: 152
                    input.verticalAlignment: TextEdit.AlignTop
                }
            }

            footerRightButtons: ObjectModel {
                StatusFlatButton {
                    text: "Cancel"
                    onClicked: popup.close()
                }

                StatusButton {
                    text: "Confirm"
                    onClicked: {
                        logs.logEvent("CommonContactAdaptiveDialog::confirm")
                        popup.close()
                    }
                }
            }

            onClosed: logs.logEvent("CommonContactAdaptiveDialog::closed")

            Component.onCompleted: open()
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumWidth: 320
        SplitView.preferredWidth: 360
        SplitView.fillHeight: true

        logsView.logText: logs.logText

        ColumnLayout {
            Layout.fillWidth: true

            Label {
                text: "Contact"
                font.bold: true
            }

            TextField {
                id: titleInput
                Layout.fillWidth: true
                text: "Contact action"
            }

            TextField {
                id: displayNameInput
                Layout.fillWidth: true
                text: "Ada Lovelace"
            }

            TextField {
                id: nicknameInput
                Layout.fillWidth: true
                placeholderText: "Local nickname"
            }

            CheckBox {
                id: isContactCheckBox
                text: "Contact"
            }

            CheckBox {
                id: trustedCheckBox
                text: "Trusted"
            }

            CheckBox {
                id: blockedCheckBox
                text: "Blocked"
            }

            Label {
                text: "Body"
                font.bold: true
                Layout.topMargin: 12
            }

            TextArea {
                id: bodyTextInput
                Layout.fillWidth: true
                text: "This page exercises the adaptive contact dialog shell with contact metadata, custom body content and footer buttons."
                wrapMode: TextEdit.WordWrap
            }
        }
    }

}

// category: Popups
