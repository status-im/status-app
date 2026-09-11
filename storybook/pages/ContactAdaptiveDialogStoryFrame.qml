pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core

import Storybook
import utils

SplitView {
    id: root

    required property Component dialogComponent
    property string contactName: "Ada Lovelace"
    property string localNickname: ""
    property bool isContact: true
    property bool isTrusted
    property bool isBlocked
    property bool showContactControls: true
    property bool showRequestControls
    property string requestMessage: "Hey, we met in the Status community. Would be great to connect."

    readonly property alias logs: logs
    readonly property string publicKey: "0x04d9f8b31df7b53f8ef91c0f5f85b0fbd9a96a9b7c2e4f6d8a1b3c5d7e9f102030405060708090a0b0c0d0e0f00112233445566778899aabbccddeeff"
    readonly property string compressedPublicKey: publicKey.substring(0, 10) + "..." + publicKey.substring(publicKey.length - 8)
    readonly property var emojiHash: ["👨🏻‍🍼", "🏃🏿‍♂️", "🌇", "🤶🏿", "🏮", "🤷🏻‍♂️", "🤦🏻", "📣", "🤎", "👷🏽", "😺", "🥞", "🔃", "🧝🏽‍♂️"]
    readonly property var contactDetails: ({
            "localNickname": localNicknameInput.text,
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
    readonly property var contactRequestDetails: ({
            "id": "contact-request-id",
            "from": publicKey,
            "clock": Date.now(),
            "text": requestMessageInput.text,
            "contactRequestState": 0
        })

    orientation: Qt.Horizontal

    Logs {
        id: logs
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
            onClicked: dialogLoader.item.open()
        }

        Loader {
            id: dialogLoader

            sourceComponent: root.dialogComponent
            onLoaded: item.open()
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
                text: root.contactName
            }

            TextField {
                id: localNicknameInput
                Layout.fillWidth: true
                text: root.localNickname
                placeholderText: "Local nickname"
            }

            CheckBox {
                id: isContactCheckBox
                text: "Contact"
                checked: root.isContact
                visible: root.showContactControls
            }

            CheckBox {
                id: trustedCheckBox
                text: "Trusted"
                checked: root.isTrusted
                visible: root.showContactControls
            }

            CheckBox {
                id: blockedCheckBox
                text: "Blocked"
                checked: root.isBlocked
                visible: root.showContactControls
            }

            Label {
                text: "Request"
                font.bold: true
                Layout.topMargin: 12
                visible: root.showRequestControls
            }

            TextArea {
                id: requestMessageInput
                Layout.fillWidth: true
                text: root.requestMessage
                wrapMode: TextEdit.WordWrap
                visible: root.showRequestControls
            }
        }
    }
}
