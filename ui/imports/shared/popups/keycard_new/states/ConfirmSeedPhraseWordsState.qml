import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Controls.Validators

Control {
    id: root

    required property string seedPhrase

    readonly property bool allEntriesValid: d.allEntriesValid

    QtObject {
        id: d

        property bool allEntriesValid: false

        readonly property var words: root.seedPhrase.split(" ")
        readonly property var wordIndices: {
            let indices = []
            while (indices.length < 3) {
                let randomIdx = Math.floor(Math.random() * 12)
                if (indices.indexOf(randomIdx) === -1)
                    indices.push(randomIdx)
            }
            indices.sort((a, b) => a < b ? -1 : a > b ? 1 : 0)
            return indices
        }

        function processText(text) {
            if (text.length === 0)
                return ""
            if (/(^\s|^\r|^\n)|(\s$|^\r$|^\n$)/.test(text))
                return text.trim()
            if (/\s|\r|\n/.test(text))
                return ""
            return text
        }

        function updateValidity() {
            d.allEntriesValid = word0.valid && word1.valid && word2.valid
        }
    }

    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding
    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding

    contentItem: ColumnLayout {
        spacing: Theme.padding

        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: qsTr("Confirm recovery phrase words")
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSize(22)
        }

        StatusInput {
            id: word0
            Layout.fillWidth: true
            validationMode: StatusInput.ValidationMode.Always
            label: qsTr("Word #%1").arg(d.wordIndices[0] + 1)
            placeholderText: qsTr("Enter word")
            input.inputMethodHints: Qt.ImhLowercaseOnly | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            validators: [
                StatusValidator {
                    validate: function(t) {
                        if (!d.words || d.words.length === 0 || word0.text.length === 0)
                            return false
                        return d.words[d.wordIndices[0]] === word0.text
                    }
                    errorMessage: word0.text.length > 0 ? qsTr("This word doesn't match") : ""
                }
            ]
            input.acceptReturn: true
            input.tabNavItem: word1.input.edit
            onTextChanged: {
                text = d.processText(text)
                d.updateValidity()
            }
        }

        StatusInput {
            id: word1
            Layout.fillWidth: true
            validationMode: StatusInput.ValidationMode.Always
            label: qsTr("Word #%1").arg(d.wordIndices[1] + 1)
            placeholderText: qsTr("Enter word")
            input.inputMethodHints: Qt.ImhLowercaseOnly | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            validators: [
                StatusValidator {
                    validate: function(t) {
                        if (!d.words || d.words.length === 0 || word1.text.length === 0)
                            return false
                        return d.words[d.wordIndices[1]] === word1.text
                    }
                    errorMessage: word1.text.length > 0 ? qsTr("This word doesn't match") : ""
                }
            ]
            input.acceptReturn: true
            input.tabNavItem: word2.input.edit
            onTextChanged: {
                text = d.processText(text)
                d.updateValidity()
            }
        }

        StatusInput {
            id: word2
            Layout.fillWidth: true
            validationMode: StatusInput.ValidationMode.Always
            label: qsTr("Word #%1").arg(d.wordIndices[2] + 1)
            placeholderText: qsTr("Enter word")
            input.inputMethodHints: Qt.ImhLowercaseOnly | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            validators: [
                StatusValidator {
                    validate: function(t) {
                        if (!d.words || d.words.length === 0 || word2.text.length === 0)
                            return false
                        return d.words[d.wordIndices[2]] === word2.text
                    }
                    errorMessage: word2.text.length > 0 ? qsTr("This word doesn't match") : ""
                }
            ]
            input.acceptReturn: true
            onTextChanged: {
                text = d.processText(text)
                d.updateValidity()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
