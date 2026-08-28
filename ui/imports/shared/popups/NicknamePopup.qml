import QtQuick
import QtQuick.Layouts
import QtQml.Models

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Controls.Validators
import StatusQ.Popups.Dialog

import shared.controls
import utils

CommonContactDialog {
    id: root

    readonly property string nickname: contactDetails.localNickname

    signal editDone(string newNickname)
    signal removeNicknameRequested()

    title: d.editMode ? qsTr("Edit nickname") : qsTr("Add nickname")

    onOpened: {
        nicknameInput.input.edit.forceActiveFocus()
    }

    readonly property var d: QtObject {
        id: d
        readonly property bool editMode: root.nickname !== ""
    }

    StatusInput {
        Layout.fillWidth: true
        id: nicknameInput
        label: qsTr("Nickname")
        input.clearable: true
        text: root.nickname
        charLimit: Constants.displayName.nameLengthMax
        validators: [
            StatusValidator {
                validatorObj: RXValidator { regularExpression: /^[\w\d_ -\.]*$/u }
                validate: (value) => validatorObj.test(value)
                errorMessage: qsTr("Invalid characters (use letters and numbers, hyphens and underscores only)")
            },
            StatusMinLengthValidator {
                minLength: Constants.displayName.nameLengthMin
                errorMessage: qsTr("Nicknames must be at least %n character(s) long", "", minLength)
            },
            StatusValidator {
                name: "startsWithSpaceValidator"
                validate: function (t) { return !(t.startsWith(" ") || t.endsWith(" "))}
                errorMessage: qsTr("Nicknames can’t start or end with a space")
            },
            StatusValidator {
                name: "endsWith-ethValidator"
                validate: function (t) { return !(t.endsWith("-eth") || t.endsWith("_eth") || t.endsWith(".eth")) }
                errorMessage: qsTr("Nicknames can’t end in “.eth”, “_eth” or “-eth”")
            },
            StatusValidator {
                name: "isAliasValidator"
                validate: function (t) { return !root.utilsStore.isAlias(t) }
                errorMessage: qsTr("Adjective-animal nickname formats are not allowed")
            }
        ]
        onKeyPressed: {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (root.nickname !== nicknameInput.text && nicknameInput.valid)
                    root.editDone(nicknameInput.text)
            }
        }
    }

    StatusBaseText {
        Layout.fillWidth: true
        text: qsTr("Nicknames help you identify others and are only visible to you")
        wrapMode: Text.WordWrap
        color: Theme.palette.baseColor1
        font.pixelSize: Theme.tertiaryTextFontSize
    }

    rightButtons: ObjectModel {
        StatusFlatButton {
            visible: !d.editMode
            text: qsTr("Cancel")
            onClicked: root.close()
        }
        StatusFlatButton {
            visible: d.editMode
            borderColor: "transparent"
            type: StatusBaseButton.Type.Danger
            text: qsTr("Remove nickname")
            onClicked: root.removeNicknameRequested()
        }
        StatusButton {
            enabled: root.nickname !== nicknameInput.text && nicknameInput.valid
            text: d.editMode ? qsTr("Change nickname") : qsTr("Add nickname")
            onClicked: root.editDone(nicknameInput.text)
        }
    }
}
