import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import AppLayouts.Wallet.controls

import Models
import Storybook

import utils

SplitView {
    id: root

    Item {
        SplitView.fillWidth: true
        NetworkSelectItemDelegate {
            anchors.centerIn: parent
            id: delegate
            text: ctrlText.text
            icon.name: ctrlIcon.text
            interactive: ctrlInteractive.checked
            showIndicator: ctrlShowIndicator.checked
            showNewIcon: ctrlShowNewIcon.checked
            checkState: checkStateSelector.checkState

            onToggled: {
                checkStateSelector.checked = checked
            }
        }
    }

    Pane {
        id: pane
        SplitView.preferredWidth: 250
        ColumnLayout {
            CheckBox {
                id: ctrlInteractive
                text: "interactive"
                checked: true
            }

            CheckBox {
                id: ctrlShowIndicator
                text: "showIndicator"
                checked: true
            }

            CheckBox {
                id: ctrlShowNewIcon
                text: "showNewIcon"
                checked: false
            }

            Label {
                text: "title"
            }
            TextField {
                id: ctrlText
                Layout.fillWidth: true
                text: "Ethereum"
            }

            Label {
                text: "icon"
            }
            TextField {
                id: ctrlIcon
                Layout.fillWidth: true
                text: "ethereum"
            }

            CheckBox {
                id: checkStateSelector
                text: "checked"
                checked: true
                onToggled: {
                    delegate.checked = checked
                }
            }
        }
    }
}

// category: Controls
// status: good
