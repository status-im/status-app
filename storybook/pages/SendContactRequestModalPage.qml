import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core

import AppLayouts.stores as AppLayoutStores
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
        readonly property string emojiHash: ""
        readonly property var contactDetails: ({
                "localNickname": nicknameInput.text,
                "name": "steady-signal",
                "displayName": displayNameInput.text,
                "alias": "Admirable Steel Signal",
                "usesDefaultName": false,
                "colorId": 5,
                "largeImage": "",
                "onlineStatus": 0,
                "isContact": false,
                "trustStatus": Constants.trustStatus.unknown,
                "isBlocked": false
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

        SendContactRequestModal {
            id: popup

            modal: false
            publicKey: d.publicKey
            compressedPublicKey: d.compressedPublicKey
            emojiHash: d.emojiHash
            contactDetails: d.contactDetails
            contactsStore: contactsStore
            labelText: labelInput.text
            challengeText: placeholderInput.text
            buttonText: buttonInput.text
            defaultMessage: defaultMessageInput.text

            onAccepted: logs.logEvent("SendContactRequestModal::accepted message=" + message)
            onClosed: logs.logEvent("SendContactRequestModal::closed")

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
                id: displayNameInput
                Layout.fillWidth: true
                text: "Ada Lovelace"
            }

            TextField {
                id: nicknameInput
                Layout.fillWidth: true
                placeholderText: "Local nickname"
            }

            Label {
                text: "Copy"
                font.bold: true
                Layout.topMargin: 12
            }

            TextField {
                id: labelInput
                Layout.fillWidth: true
                text: "Why should they accept your contact request?"
            }

            TextField {
                id: placeholderInput
                Layout.fillWidth: true
                text: "Write a short message telling them who you are..."
            }

            TextField {
                id: buttonInput
                Layout.fillWidth: true
                text: "Send contact request"
            }

            TextArea {
                id: defaultMessageInput
                Layout.fillWidth: true
                placeholderText: "Default message"
                wrapMode: TextEdit.WordWrap
            }
        }
    }

    AppLayoutStores.ContactsStore {
        id: contactsStore

        function requestContactInfo(publicKey) {
            logs.logEvent("ContactsStore::requestContactInfo publicKey=" + publicKey)
            contactInfoRequestFinished(publicKey, true)
        }

        signal contactInfoRequestFinished(string publicKey, bool ok)
    }

}

// category: Popups
