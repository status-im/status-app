import QtQuick
import QtQuick.Layouts
import QtQml.Models

import utils

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Controls.Validators
import StatusQ.Popups.Dialog
import StatusQ.Core.Utils as SQUtils

import AppLayouts.stores as AppLayoutStores

CommonContactDialog {
    id: root

    property AppLayoutStores.ContactsStore contactsStore

    property string labelText: qsTr("Why should they accept your contact request?")
    property string challengeText: qsTr("Write a short message telling them who you are...")
    property string buttonText: qsTr("Send contact request")
    property string defaultMessage: ""

    signal accepted(string message)

    title: qsTr("Send contact request")

    onAboutToShow: {
        if (root.defaultMessage)
            messageInput.text = root.defaultMessage
        messageInput.input.edit.forceActiveFocus()

        // (request) update from mailserver
        if (root.contactDetails.displayName === "") {
            root.contactsStore.requestContactInfo(root.publicKey)
            root.loadingContactDetails = true
        }
    }

    readonly property var d: QtObject {
        id: d

        readonly property int maxMsgLength: 280
        readonly property int minMsgLength: 1
        readonly property int msgHeight: 152
    }

    readonly property var _conn: Connections {
        enabled: root.loadingContactDetails
        target: root.contactsStore

        function onContactInfoRequestFinished(publicKey, ok) {
            if (publicKey !== root.publicKey) {
                return
            }
            if (ok) {
                root.contactDetails = SQUtils.ModelUtils.getByKey(root.contactsStore.contactsModel, "pubKey", root.publicKey)
            }
            root.loadingContactDetails = false
        }
    }

    StatusInput {
        id: messageInput
        input.edit.objectName: "ProfileSendContactRequestModal_sayWhoYouAreInput"
        Layout.fillWidth: true
        label: root.labelText
        charLimit: d.maxMsgLength
        placeholderText: root.challengeText
        input.multiline: true
        minimumHeight: d.msgHeight
        maximumHeight: d.msgHeight
        input.verticalAlignment: TextEdit.AlignTop
        validators: StatusMinLengthValidator {
            minLength: d.minMsgLength
            errorMessage: Utils.getErrorMessage(messageInput.errors, qsTr("who are you"))
        }
    }

    rightButtons: ObjectModel {
        StatusFlatButton {
            text: qsTr("Cancel")
            onClicked: root.close()
        }
        StatusButton {
            objectName: "ProfileSendContactRequestModal_sendContactRequestButton"
            enabled: messageInput.valid
            text: root.buttonText
            onClicked: {
                root.accepted(messageInput.text);
                root.close();
            }
        }
    }
}
