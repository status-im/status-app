import QtQuick
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups.Dialog
import StatusQ.Core.Utils as StatusQUtils

import AppLayouts.Profile.controls
import AppLayouts.Wallet

import shared.panels
import utils

StatusDialog {
    id: root

    property string name
    property var relatedAccounts

    signal confirmClicked()

    title: qsTr("Remove %1 key pair").arg(name)
    width: 521

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.xlPadding

        StatusBaseText {
            Layout.fillWidth: true
            text: qsTr("Are you sure you want to remove %1 key pair? The key pair will be removed from all of your synced devices. Make sure you have a backup of your keys or recovery phrase before proceeding.").arg(name)
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.primaryTextFontSize
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            StatusBaseText {
                text: qsTr("Accounts related to this key pair will also be removed:")
                font.pixelSize: Theme.primaryTextFontSize
            }

            StatusScrollView {
                id: scrolView1
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                Rectangle {
                    implicitWidth: scrolView1.availableWidth
                    implicitHeight: listview.height
                    color: StatusColors.transparent
                    border.color: Theme.palette.baseColor2
                    border.width: 1
                    radius: 8
                    clip: true
                    Column {
                        id: listview
                        width: scrolView1.availableWidth
                        Repeater {
                            id: repeater
                            model: root.relatedAccounts
                            delegate: WalletAccountDelegate {
                                id: delegate
                                width: parent.width
                                account : model.account
                                color: StatusColors.transparent
                                nextIconVisible: false
                                compIndex: index
                                components: StatusBaseText {
                                    font.pixelSize: Theme.primaryTextFontSize
                                    text: LocaleUtils.currencyAmountToLocaleString(!!account ? account.balance: "")
                                }
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: 1
                                    color: Theme.palette.baseColor2
                                    visible: index < repeater.count - 1
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    footer: StatusDialogFooter {
        rightButtons: ObjectModel {
            StatusButton {
                text: qsTr("Cancel")
                onClicked : root.close()
            }
            StatusButton {
                type: StatusBaseButton.Type.Danger
                text: qsTr("Remove key pair and derived accounts")
                onClicked: root.confirmClicked()
                Keys.onReturnPressed: function(event) {
                    root.confirmClicked()
                }
            }
        }
    }
}
