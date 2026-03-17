import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Controls.Validators

import utils
import "../controls"

Item {
    id: root

    property alias displayName: displayNameInput
    property alias bio: bioInput

    implicitHeight: layout.implicitHeight
    implicitWidth: layout.implicitWidth

    ColumnLayout {
        id: layout
        anchors.fill: parent

        spacing: 19 // by design

        StatusInput {
            id: displayNameInput
            objectName: "displayNameInput"

            Layout.fillWidth: true

            allowEmpty: true
            label: qsTr("Display name")
            placeholderText: qsTr("Display Name")
            charLimit: Constants.keypair.nameLengthMax

            input.tabNavItem: bioInput.input.edit
        }


        StatusInput {
            id: bioInput
            objectName: "bioInput"

            Layout.fillWidth: true
            Layout.topMargin: 5 // by design

            label: qsTr("Bio")
            placeholderText: qsTr("Tell us about yourself")
            input.maximumLength : 32767
            charLimit: 240
            multiline: true
            minimumHeight: 108
            maximumHeight: 108
            input.verticalAlignment: TextEdit.AlignTop
            validationMode: StatusInput.ValidationMode.Always
            validators: [
                StatusValidator {
                    name: "maxLengthValidator"
                    validate: function (t) { return t.length <= bioInput.charLimit}
                    errorMessage: qsTr("Bio can't be longer than %n character(s)", "", bioInput.charLimit)
                },
                StatusRegularExpressionValidator {
                    regularExpression: Constants.regularExpressions.asciiWithEmoji
                    errorMessage: qsTr("Invalid characters. Standard keyboard characters and emojis only.")
                    validate: function (value) {
                        return (regularExpression.test(value) || (value.length === 0));
                    }
                }
            ]
            input.tabNavItem: displayNameInput.input.edit
        }
    }
}
