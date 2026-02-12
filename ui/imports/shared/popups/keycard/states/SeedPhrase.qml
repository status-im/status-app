import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls

import utils
import shared.panels as SharedPanels

Control {
    id: root

    property var sharedKeycardModule
    property alias seedPhraseRevealed: displaySeed.seedPhraseRevealed

    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding
    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding

    contentItem: ColumnLayout {
        spacing: Theme.padding

        TitleText {
            id: title
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        StatusBaseText {
            id: message
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        SharedPanels.SeedPhrase {
            id: displaySeed
            Layout.fillWidth: true

            seedPhrase: root.sharedKeycardModule.getMnemonic().split(" ")
        }
    }

    states: [
        State {
            name: Constants.keycardSharedState.seedPhraseDisplay
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.seedPhraseDisplay
            PropertyChanges {
                target: title
                text: qsTr("Write down your recovery phrase")
            }
            PropertyChanges {
                target: message
                text: qsTr("The next screen contains your recovery phrase.<br/><b>Anyone</b> who sees it can use it to access to your funds.")
                wrapMode: Text.WordWrap
                textFormat: Text.RichText
                color: Theme.palette.dangerColor1
            }
        }
    ]
}
