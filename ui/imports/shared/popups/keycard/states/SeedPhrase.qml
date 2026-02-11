import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls

import utils
import shared.panels as SharedPanels

Item {
    id: root

    property var sharedKeycardModule
    property alias seedPhraseRevealed: displaySeed.seedPhraseRevealed

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Theme.xlPadding
        anchors.bottomMargin: Theme.halfPadding
        anchors.leftMargin: Theme.xlPadding
        anchors.rightMargin: Theme.xlPadding
        spacing: Theme.padding

        TitleText {
            id: title
            Layout.preferredHeight: Constants.keycard.general.titleHeight
            Layout.alignment: Qt.AlignCenter
            Layout.fillWidth: true

            wrapMode: Text.WordWrap
        }

        StatusBaseText {
            id: message
            Layout.preferredHeight: Constants.keycard.general.messageHeight
            Layout.alignment: Qt.AlignCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        SharedPanels.SeedPhrase {
            id: displaySeed
            Layout.preferredWidth: parent.width
            Layout.fillHeight: true

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
