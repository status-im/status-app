import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils

import StatusQ
import StatusQ.Controls
import StatusQ.Controls.Validators
import StatusQ.Core
import StatusQ.Core.Backpressure
import StatusQ.Core.Theme
import StatusQ.Popups

import AppLayouts.Profile.stores
import AppLayouts.stores as AppLayoutStores

StatusModal {
    id: root

    property AppLayoutStores.ContactsStore contactsStore

    headerSettings.title: qsTr("Send Contact Request to chat key")
    padding: d.contentMargins

    QtObject {
        id: d

        readonly property int maxMsgLength: 280
        readonly property int minMsgLength: 1
        readonly property int msgHeight: 152
        readonly property int contentSpacing: 5
        readonly property int contentMargins: 16

        property int minChatKeyLength: 4 // ens or chat key
        property string realChatKey: ""
        property string resolvedPubKey: ""
        property string elidedChatKey: realChatKey.length > 32?
                                           realChatKey.substring(0, 15) + "..." + realChatKey.substring(realChatKey.length - 16) :
                                           realChatKey

        property bool validChatKey: false
        property bool showPasteButton: true
        property bool showChatKeyValidationIndicator: false
        property int showChatKeyValidationIndicatorSize: 24

        property var lookupContact: Backpressure.debounce(root, 400, function (value) {
            root.contactsStore.resolveENS(value)
        })

        function textChanged(text) {
            const urlContactData = Utils.parseContactUrl(text)
            if (urlContactData) {
                // Ignore all the data from the link, because it might be malformed.
                // Except for the publicKey.
                d.realChatKey = urlContactData.publicKey
                Qt.callLater(d.lookupContact, urlContactData.publicKey);
                return
            }

            d.resolvedPubKey = ""
            d.realChatKey = text

            if(d.realChatKey === "") {
                d.showPasteButton = true
                d.showChatKeyValidationIndicator = false
            }

            if (text.length < d.minChatKeyLength) {
                d.validChatKey = false
                return
            }

            if (Utils.isStatusDeepLink(text)) {
                text = Utils.getChatKeyFromShareLink(text)
            }
            Qt.callLater(d.lookupContact, text);
        }
    }

    Connections {
        target: root.contactsStore

        function onResolvedENS(resolvedPubKey: string, resolvedAddress: string, uuid: string) {
            if(!d.showChatKeyValidationIndicator){
                d.showPasteButton = false
                d.showChatKeyValidationIndicator = true
            }
            d.resolvedPubKey = resolvedPubKey
            d.validChatKey = (resolvedPubKey !== "")
        }
    }

    Component {
        id: chatKeyValidationIndicator
        Item {
            implicitWidth: d.showChatKeyValidationIndicatorSize
            implicitHeight: d.showChatKeyValidationIndicatorSize
            anchors.verticalCenter: parent.verticalCenter
            StatusIcon {
                anchors.fill: parent
                icon: d.validChatKey? "checkmark-circle" : "close-circle"
                color: d.validChatKey? Theme.palette.successColor1 : Theme.palette.dangerColor1
            }
        }
    }

    Component {
        id: pasteButtonComponent
        StatusButton {
            anchors.verticalCenter: parent.verticalCenter
            borderColor: Theme.palette.primaryColor1
            size: StatusBaseButton.Size.Tiny
            text: qsTr("Paste")
            onClicked: {
                d.realChatKey = ClipboardUtils.text
                d.showPasteButton = false
                d.textChanged(d.realChatKey)
            }
        }
    }

    contentItem: Column {
        id: content
        spacing: d.contentSpacing

        StatusInput {
            id: chatKeyInput
            input.edit.objectName: "SendContactRequestModal_ChatKey_Input"
            width: parent.width
            placeholderText: qsTr("Enter chat key here")
            input.text: input.edit.focus? d.realChatKey : d.elidedChatKey
            input.rightComponent: {
                if(d.showPasteButton)
                    return pasteButtonComponent
                else if(d.showChatKeyValidationIndicator)
                    return chatKeyValidationIndicator
                else
                    return null
            }
            input.onTextChanged: {
                if(input.edit.focus)
                {
                    d.textChanged(text)
                }
            }
        }

        StatusInput {
            id: messageInput
            input.edit.objectName: "SendContactRequestModal_SayWhoYouAre_Input"
            charLimit: d.maxMsgLength
            width: parent.width
            placeholderText: qsTr("Say who you are / why you want to become a contact...")
            input.multiline: true
            minimumHeight: d.msgHeight
            maximumHeight: d.msgHeight
            input.verticalAlignment: TextEdit.AlignTop

            validators: [StatusMinLengthValidator {
                    minLength: d.minMsgLength
                    errorMessage: Utils.getErrorMessage(messageInput.errors, qsTr("who are you"))
                }]
        }
    }

    rightButtons: [
        StatusButton {
            enabled: d.validChatKey && messageInput.valid
            objectName: "SendContactRequestModal_Send_Button"
            text: qsTr("Send Contact Request")
            onClicked: {
                root.contactsStore.sendContactRequest(d.resolvedPubKey, messageInput.text)
                root.close()
            }
        }
    ]
}
