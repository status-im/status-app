import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups.Dialog

import shared.controls

import utils

import AppLayouts.Browser.adapters

StatusDialog {
    id: root

    property QtObject request

    width: 300
    implicitHeight: 286
    title: request.securityOrigin
    closePolicy: Popup.NoAutoClose
    destroyOnClose: true

    contentItem: ColumnLayout {
        StatusScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: request.type === AbstractWebView.JavaScriptDialogType.DialogTypePrompt ? 75 : 100
            StatusTextArea {
                readOnly: true
                text: request.message
            }
        }

        Input {
            Layout.fillWidth: true
            id: prompt
            text: request.defaultText
            visible: request.type === AbstractWebView.JavaScriptDialogType.DialogTypePrompt
        }
    }

    footer: StatusDialogFooter {
        rightButtons: ObjectModel {
            StatusFlatButton {
                text: qsTr("Cancel")
                visible: request.type !== AbstractWebView.JavaScriptDialogType.DialogTypeAlert
                onClicked: {
                    request.dialogReject()
                    root.close()
                }
            }
            StatusButton {
                text: qsTr("OK")
                onClicked: {
                    request.dialogAccept(prompt.text)
                    root.close()
                }
            }
        }
    }
}
