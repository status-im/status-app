import QtQuick
import QtQuick.Layouts
import QtQml.Models

import StatusQ
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Controls.Validators
import StatusQ.Popups.Dialog

import utils

StatusDialog {
    id: root

    required property bool incognitoMode

    property string ogUrl: ""
    property string ogName: ""
    property bool editMode: false

    signal addBookmarkRequested(string url, string name)
    signal editBookmarkRequested(string oldUrl, string newUrl, string newName)
    signal deleteBookmarkRequested(string url)

    width: 560
    modal: true

    title: editMode ? qsTr("Edit bookmark") : qsTr("Add bookmark")

    contentItem: ColumnLayout {
        spacing: Theme.padding

        StatusInput {
            Layout.fillWidth: true
            id: urlInput
            label: qsTr("URL")
            input.text: root.ogUrl
            placeholderText: qsTr("Paste URL")
            input.rightComponent: StatusButton {
                anchors.verticalCenter: parent.verticalCenter
                borderColor: Theme.palette.primaryColor1
                size: StatusBaseButton.Size.Tiny
                text: qsTr("Paste")
                visible: ClipboardUtils.hasText && Utils.isURL(ClipboardUtils.text)
                onClicked: {
                    text = qsTr("Pasted")
                    urlInput.text = ClipboardUtils.text
                }
            }
            validators: [
                StatusUrlValidator {}
            ]
            validationMode: StatusInput.ValidationMode.Always
            input.tabNavItem: nameInput
        }

        StatusInput {
            Layout.fillWidth: true
            id: nameInput
            label: qsTr("Name")
            input.text: root.ogName
            placeholderText: qsTr("Name of the website")
            validators: [
                StatusMinLengthValidator {
                    errorMessage: qsTr("Please enter a name")
                    minLength: 1
                }
            ]
            validationMode: StatusInput.ValidationMode.Always
            input.tabNavItem: urlInput
        }
    }

    footer: StatusDialogFooter {
        rightButtons: ObjectModel {
            StatusButton {
                visible: root.editMode
                text: qsTr("Delete")
                type: StatusBaseButton.Type.Danger
                onClicked: {
                    root.deleteBookmarkRequested(root.ogUrl)
                    root.close()
                }
            }

            StatusButton {
                text: root.editMode ? qsTr("Save changes") : qsTr("Add")
                type: StatusBaseButton.Type.Primary
                enabled: nameInput.valid && urlInput.valid
                onClicked: {
                    if (!root.editMode) {
                        // remove "add favorite" button at the end, add new bookmark, add "add favorite" button back
                        root.deleteBookmarkRequested(Constants.newBookmark)
                        root.addBookmarkRequested(urlInput.text, nameInput.text)
                        root.addBookmarkRequested(Constants.newBookmark, qsTr("Add bookmark"))
                    } else if (root.ogName !== nameInput.text || root.ogUrl !== urlInput.text) {
                        root.editBookmarkRequested(root.ogUrl, urlInput.text, nameInput.text)
                    }
                    root.close()
                }
            }
        }
    }
}
