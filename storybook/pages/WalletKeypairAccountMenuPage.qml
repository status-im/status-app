import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import AppLayouts.Profile.popups

import utils

SplitView {
    id: root

    Rectangle {
        SplitView.fillWidth: true
        SplitView.fillHeight: true
        color: Theme.palette.statusAppLayout.rightPanelBackgroundColor
        clip: true

        Button {
            anchors.centerIn: parent
            text: "Show menu"
            onClicked: menu.popup()
        }

        WalletKeypairAccountMenu {
            id: menu
            anchors.centerIn: parent
            keyPair: keyPairMock
        }
    }

    Pane {
        SplitView.minimumWidth: 280
        SplitView.preferredWidth: 280

        ColumnLayout {
            anchors.fill: parent
            spacing: 16

            Label {
                text: "pairType"
            }
            ComboBox {
                id: pairTypeCombo
                Layout.fillWidth: true
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: "profile", value: Constants.keypair.type.profile },
                    { text: "seedImport", value: Constants.keypair.type.seedImport },
                    { text: "privateKeyImport", value: Constants.keypair.type.privateKeyImport }
                ]
                currentIndex: 2
            }
        }

        QtObject {
            id: keyPairMock
            property string name: "Imported key pair"
            property int pairType: pairTypeCombo.currentValue
        }
    }
}

// category: Wallet
// status: good
