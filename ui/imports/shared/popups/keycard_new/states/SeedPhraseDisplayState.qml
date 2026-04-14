import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme

import shared.panels as SharedPanels

Control {
    id: root

    required property string seedPhrase

    property alias seedPhraseRevealed: displaySeed.seedPhraseRevealed

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
            text: qsTr("Write down your recovery phrase")
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSize(22)
        }

        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            textFormat: Text.RichText
            text: qsTr("The next screen contains your recovery phrase.<br/><b>Anyone</b> who sees it can use it to access to your funds.")
            color: Theme.palette.dangerColor1
        }

        SharedPanels.SeedPhrase {
            id: displaySeed
            Layout.fillWidth: true
            seedPhrase: root.seedPhrase.split(" ")
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
