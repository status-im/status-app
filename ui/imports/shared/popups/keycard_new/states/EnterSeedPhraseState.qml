import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme

import shared
import shared.panels as SharedPanels

import utils

Control {
    id: root

    signal seedPhraseValidated(string seedPhrase, string keyUid)

    // Function to validate and get keyUid for the seed phrase, must be provided by parent
    required property var validateSeedPhrase

    property bool seedPhraseValid: false
    property string validatedSeedPhrase: ""

    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding
    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding

    contentItem: ColumnLayout {
        spacing: Theme.padding

        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: qsTr("Enter recovery phrase")
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSize(22)
        }

        SharedPanels.EnterSeedPhrase {
            id: seedPhraseInput

            Layout.fillWidth: true

            dictionary: BIP39_en {}

            onSeedPhraseProvided: function(seedPhrase) {
                const phrase = seedPhrase.join(" ")
                const keyUid = root.validateSeedPhrase(phrase)
                if (keyUid.length > 0) {
                    root.seedPhraseValid = true
                    root.validatedSeedPhrase = phrase
                    setError("")
                    root.seedPhraseValidated(phrase, keyUid)
                } else {
                    root.seedPhraseValid = false
                    root.validatedSeedPhrase = ""
                    setError(qsTr("Invalid recovery phrase"))
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
