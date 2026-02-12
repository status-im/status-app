import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

import StatusQ.Core
import StatusQ.Controls

Control {
    id: root

    property var seedPhrase: []
    property bool seedPhraseRevealed: false

    implicitHeight: grid.contentHeight
    implicitWidth: grid.contentWidth

    contentItem: StatusGridView {
        id: grid
        cellWidth: parent.width * 0.5
        cellHeight: 48
        interactive: false
        visible: root.seedPhraseRevealed
        model: 12
        readonly property var wordIndex: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"]
        readonly property int spacing: 4
        delegate: StatusSeedPhraseInput {
            objectName: "SeedPhraseWordAtIndex-" + grid.wordIndex[index]
            width: (grid.cellWidth - grid.spacing)
            height: (grid.cellHeight - grid.spacing)
            textEdit.input.edit.enabled: false
            text: {
                const idx = parseInt(leftComponentText) - 1;
                if (!root.seedPhrase || idx < 0 || idx > root.seedPhrase.length - 1)
                    return "";
                return root.seedPhrase[idx];
            }
            leftComponentText: grid.wordIndex[index]
        }
    }

    GaussianBlur {
        id: blur
        anchors.fill: contentItem
        visible: !root.seedPhraseRevealed
        source: grid
        radius: 16
        samples: 16
        transparentBorder: true
    }

    StatusButton {
        objectName: "AddAccountPopup-RevealSeedPhrase"
        anchors.centerIn: parent
        visible: !root.seedPhraseRevealed
        type: StatusBaseButton.Type.Primary
        icon.name: "view"
        text: qsTr("Reveal recovery phrase")
        onClicked: {
            root.seedPhraseRevealed = true
        }
    }
}
