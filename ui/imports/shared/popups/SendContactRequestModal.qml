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

CommonContactAdaptiveDialog {
    id: root

    objectName: "SendContactRequestModal"

    property AppLayoutStores.ContactsStore contactsStore

    property string labelText: qsTr("Why should they accept your contact request?")
    property string challengeText: qsTr("Write a short message telling them who you are...")
    property string buttonText: qsTr("Send contact request")
    property string defaultMessage: ""
    property string message: defaultMessage

    title: qsTr("Send contact request")

    onAboutToShow: {
        root.message = root.defaultMessage

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
        property bool messageValid: false
    }

    readonly property var _conn: Connections {
        enabled: root.loadingContactDetails
        target: root.contactsStore

        function onContactInfoRequestFinished(publicKey, ok) {
            if (publicKey !== root.publicKey) {
                return
            }
            root.loadingContactDetails = false
        }
    }

    bodyComponent: ColumnLayout {
        spacing: Theme.halfPadding

        StatusBaseText {
            Layout.fillWidth: true
            visible: !!root.labelText
            text: root.labelText
            wrapMode: Text.WordWrap
            color: Theme.palette.directColor1
        }

        StatusInput {
            id: messageInput
            input.edit.objectName: "ProfileSendContactRequestModal_sayWhoYouAreInput"
            Layout.fillWidth: true
            charLimit: d.maxMsgLength
            placeholderText: root.challengeText
            input.multiline: true
            minimumHeight: d.msgHeight
            maximumHeight: d.msgHeight
            input.verticalAlignment: TextEdit.AlignTop
            text: root.message
            validators: StatusMinLengthValidator {
                minLength: d.minMsgLength
                errorMessage: Utils.getErrorMessage(messageInput.errors, qsTr("who are you"))
            }

            onTextChanged: root.message = text
            onValidChanged: d.messageValid = valid
            Component.onCompleted: {
                d.messageValid = valid
                input.edit.forceActiveFocus()
            }
        }
    }

    footerRightButtons: ObjectModel {
        StatusFlatButton {
            text: qsTr("Cancel")
            onClicked: root.close()
        }
        StatusButton {
            objectName: "ProfileSendContactRequestModal_sendContactRequestButton"
            enabled: d.messageValid
            text: root.buttonText
            onClicked: {
                root.accept()
            }
        }
    }
}
