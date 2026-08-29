import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook
import Models

import AppLayouts.Communities.popups
import AppLayouts.Communities.helpers

SplitView {
    Logs { id: logs }

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        Item {
            SplitView.fillWidth: true
            SplitView.fillHeight: true

            PopupBackground {
                anchors.fill: parent
            }

            Button {
                anchors.centerIn: parent
                text: "Reopen"

                onClicked: dialog.open()
            }

            TransferOwnershipAlertPopup {
                id: dialog

                closePolicy: Popup.NoAutoClose
                visible: true
                modal: false

                communityName: communityNameText.text
                communityLogo: ModelsData.collectibles.doodles

                onCancelClicked: logs.logEvent("TransferOwnershipAlertPopup::onCancelClicked")
                onMintClicked: logs.logEvent("TransferOwnershipAlertPopup::onMintClicked")
            }
        }

        LogsAndControlsPanel {
            id: logsAndControlsPanel

            SplitView.minimumHeight: 100
            SplitView.preferredHeight: 150

            logsView.logText: logs.logText
        }
    }

    Pane {
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 300

        Column {
            spacing: 12

            Label {
                text: "Community Name"
                font.bold: true
            }

            TextInput {
                id: communityNameText

                text: "Doodles"

            }

            Label {
                text: "Community Logo"
                font.bold: true
            }

            Column {

                RadioButton {
                    id: doodleLogo

                    text: "Doodle"
                    checked: true

                    onCheckedChanged: dialog.communityLogo =  ModelsData.collectibles.doodles
                }

                RadioButton {
                    id: manaLogo

                    text: "Mana"

                    onCheckedChanged: dialog.communityLogo =  ModelsData.collectibles.mana
                }

                RadioButton {
                    id: superRareLogo

                    text: "Status"

                    onCheckedChanged: dialog.communityLogo =  ModelsData.collectibles.custom
                }
            }

            Label {
                text: "Mode"
                font.bold: true
            }

            Column {

                RadioButton {
                    id: transferMode

                    text: "Transfer Ownership"
                    checked: true

                    onCheckedChanged: dialog.mode = TransferOwnershipAlertPopup.Mode.TransferOwnership
                }

                RadioButton {
                    id: moveNodeMode

                    text: "Move Control Node"

                    onCheckedChanged: dialog.mode = TransferOwnershipAlertPopup.Mode.MoveControlNode
                }
            }
        }
    }
}

// category: Popups

// https://www.figma.com/file/qHfFm7C9LwtXpfdbxssCK3/Kuba%E2%8E%9CDesktop---Communities?type=design&node-id=37206%3A86828&mode=design&t=coHVo1E6fHrKNNhQ-1
// https://www.figma.com/file/qHfFm7C9LwtXpfdbxssCK3/Kuba%E2%8E%9CDesktop---Communities?type=design&node-id=37206%3A86847&mode=design&t=coHVo1E6fHrKNNhQ-1
