import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

import shared.popups
import utils

import AppLayouts.Wallet.stores

import Storybook
import Models
import Mocks

SplitView {
    SplitView {
        id: root

        orientation: Qt.Vertical
        SplitView.fillWidth: true

        Logs { id: logs }

        readonly property WalletAssetsStoreMock walletAssetStore: WalletAssetsStoreMock {
        }

        function openDialog() {
            popupComponent.createObject(popupBg)
        }

        Component.onCompleted: openDialog()

        Component {
            id: popupComponent
            CommunityMembershipSetupDialog {
                anchors.centerIn: parent
                modal: false
                visible: true
                closePolicy: Popup.NoAutoClose
                destroyOnClose: true

                isEditMode: ctrlIsEditMode.checked
                communityId: "ddls"
                communityName: ctrlCommunityName.text
                communityIcon: {
                    if (ctrlIconStatus.checked)
                        return ModelsData.icons.status
                    if (ctrlIconCryptoPunks.checked)
                        return ModelsData.icons.cryptPunks
                    if (ctrlIconRarible.checked)
                        return ModelsData.icons.rarible
                    if (ctrlIconNone.checked)
                        return ""
                }

                introMessage: ctrlIntro.text.arg(communityName)

                isInvitationPending: ctrlIsInvitationPending.checked
                requirementsCheckPending: ctrlRequirementsCheckPending.checked
                checkingPermissionToJoinInProgress: ctrlCheckingPermissionToJoinInProgress.checked
                joinPermissionsCheckCompletedWithoutErrors: ctrlJoinPermissionsCheckCompletedWithoutErrors.checked

                walletAccountsModel: WalletAccountsModel {}
                walletAssetsModel: root.walletAssetStore.groupedAccountAssetsModel
                walletCollectiblesModel: ManageCollectiblesModel {}
                permissionsModel: ctrlPermissionsModel.currentValue
                assetsModel: AssetsModel {}
                collectiblesModel: CollectiblesModel {}

                onCancelMembershipRequest: logs.logEvent("CommunityMembershipSetupDialog::onCancelMembershipRequest()")

                onPrepareForSigning: logs.logEvent("CommunityMembershipSetupDialog::onPrepareForSigning", ["airdropAddress", "sharedAddresses"], arguments)
                onJoinCommunity: logs.logEvent("CommunityMembershipSetupDialog::onJoinCommunity")
                onEditRevealedAddresses: logs.logEvent("CommunityMembershipSetupDialog::editRevealedAddresses")
                onSignSharedAddressesForKeypair: logs.logEvent("CommunityMembershipSetupDialog::onSignSharedAddressesForKeypair", ["keyUid"], arguments)
                onSharedAddressesUpdated: logs.logEvent("CommunityMembershipSetupDialog::onSharedAddressesUpdated", ["sharedAddresses"], arguments)
                getCurrencyAmount: function (balance, symbol) {
                    return ({
                                amount: balance,
                                symbol: symbol.toUpperCase(),
                                displayDecimals: 2,
                                stripTrailingZeroes: false
                            })
                }
            }
        }

        Item {
            SplitView.fillWidth: true
            SplitView.fillHeight: true

            PopupBackground {
                id: popupBg
                anchors.fill: parent
            }

            Button {
                anchors.centerIn: parent
                text: "Reopen"

                onClicked: root.openDialog()
            }
        }

        LogsAndControlsPanel {
            id: logsAndControlsPanel

            SplitView.minimumHeight: 100
            SplitView.preferredHeight: 200

            logsView.logText: logs.logText
        }
    }

    Pane {
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 300

        ColumnLayout {
            anchors.fill: parent

            Label {
                Layout.fillWidth: true
                text: "Community name"
                font.weight: Font.Bold
            }

            TextField {
                id: ctrlCommunityName
                Layout.fillWidth: true
                text: "Status"
            }

            Label {
                Layout.fillWidth: true
                text: "Intro"
                font.weight: Font.Bold
            }

            TextField {
                id: ctrlIntro
                Layout.fillWidth: true
                text: "%1 sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo.

1. Ut enim ad minim veniam
2. Excepteur sint occaecat cupidatat non proident
3. Duis aute irure
4. Dolore eu fugiat nulla pariatur
5. 🚗 consectetur adipiscing elit

Nemo enim 😋 ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt."
            }

            ColumnLayout {
                Label {
                    Layout.fillWidth: true
                    text: "Icon:"
                    font.weight: Font.Bold
                }
                RadioButton {
                    id: ctrlIconStatus
                    checked: true
                    text: "Status"
                }
                RadioButton {
                    id: ctrlIconCryptoPunks
                    text: "Crypto Punks"
                }
                RadioButton {
                    id: ctrlIconRarible
                    text: "Rarible"
                }
                RadioButton {
                    id: ctrlIconNone
                    text: "None"
                }
            }

            CheckBox {
                id: ctrlIsInvitationPending
                text: "Is invitation pending"
            }

            CheckBox {
                id: ctrlIsEditMode
                visible: !ctrlIsInvitationPending.checked
                text: "Is edit mode"
            }

            ColumnLayout {
                visible: !ctrlIsInvitationPending.checked

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    Label {
                        text: "Permissions:"
                    }
                    ComboBox {
                        Layout.fillWidth: true
                        id: ctrlPermissionsModel
                        textRole: "text"
                        valueRole: "value"
                        model: [
                            { value: PermissionsModel.complexCombinedPermissionsModel, text: "complexCombined" },
                            { value: PermissionsModel.complexCombinedPermissionsModelNotMet, text: "complexCombinedNotMet" },
                            { value: PermissionsModel.complexPermissionsModel, text: "complex" },
                            { value: PermissionsModel.complexPermissionsModelNotMet, text: "complexNotMet" },
                            { value: PermissionsModel.channelsOnlyPermissionsModel, text: "channelsOnly" },
                            { value: PermissionsModel.channelsOnlyPermissionsModelNotMet, text: "channelsOnlyNotMet" },
                            { value: null, text: "null" }
                        ]
                    }
                }
            }

            CheckBox {
                Layout.leftMargin: 12
                id: ctrlRequirementsCheckPending
                visible: !ctrlIsInvitationPending.checked
                text: "Requirements check pending"
            }

            CheckBox {
                Layout.leftMargin: 20
                id: ctrlCheckingPermissionToJoinInProgress
                enabled: !ctrlRequirementsCheckPending.checked
                visible: !ctrlIsInvitationPending.checked
                text: "Checking perms to join"

                Binding on checked {
                    when: ctrlRequirementsCheckPending.checked
                    value: true
                    restoreMode: Binding.RestoreValue
                }
            }

            CheckBox {
                Layout.leftMargin: 12
                id: ctrlJoinPermissionsCheckCompletedWithoutErrors
                visible: !ctrlIsInvitationPending.checked
                text: "Join perm. check completed w/o errors"
                checked: true
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}

// category: Popups

// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=31461%3A563897&mode=dev
