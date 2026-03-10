import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import shared.controls
import shared.popups

import utils

import AppLayouts.Browser.adapters

// TODO: replace with StatusDialog
ModalPopup {
    id: root
    property QtObject request
    height: 286

    closePolicy: Popup.NoAutoClose

    onClosed: {
        request.dialogReject();
        root.destroy();
    }

    Component.onCompleted: {
        root.title = request.securityOrigin;
        message.text = request.message;
        if(request.type === AbstractWebView.JavaScriptDialogType.DialogTypeAlert) {
            cancelButton.visible = false;
        }
        if(request.type === AbstractWebView.JavaScriptDialogType.DialogTypePrompt) {
            prompt.text = request.defaultText;
            prompt.visible = true;
            svMessage.height = 75;
        }
    }

    StatusScrollView {
        id: svMessage
        width: parent.width
        height: 100
        TextArea {
            id: message
            wrapMode: TextEdit.Wrap
            readOnly: true
            text: ""
        }
    }

    Input {
        id: prompt
        text: ""
        visible: false
        anchors.top: svMessage.bottom
        anchors.right: parent.right
        anchors.left: parent.left
    }

    footer: Item {
        width: parent.width
        height: okButton.height

        StatusButton {
            id: okButton
            anchors.right: parent.right
            text: qsTr("OK")
            anchors.bottom: parent.bottom
            onClicked: {
                request.dialogAccept(prompt.text);
                close();
            }
        }

        StatusFlatButton {
            id: cancelButton
            anchors.right: okButton.left
            anchors.rightMargin: Theme.smallPadding
            text: qsTr("Cancel")
            anchors.bottom: parent.bottom
            onClicked: {
                request.dialogReject();
                close();
            }
        }
    }
}
