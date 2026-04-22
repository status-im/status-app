import QtQuick
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups

import utils

import AppLayouts.Profile.popups

Rectangle {
    id: root

    property var keyPair
    property bool hasPairedDevices
    property string userProfilePublicKey

    signal goToAccountView(var account)
    signal runExportQrFlow()
    signal runImportViaQrFlow()
    signal runImportViaSeedPhraseFlow()
    signal runImportViaPrivateKeyFlow()
    signal runRenameKeypairFlow()
    signal runRemoveKeypairFlow()
    signal runMoveKeypairToKeycardFlow()
    signal runStopUsingKeycardFlow()

    QtObject {
        id: d
        readonly property var relatedAccounts: !!root.keyPair? root.keyPair.accounts : {}
        readonly property bool isWatchOnly: !!root.keyPair && root.keyPair.pairType === Constants.keypair.type.watchOnly
        readonly property bool isProfileKeypair: !!root.keyPair && root.keyPair.pairType === Constants.keypair.type.profile
    }

    implicitHeight: layout.height
    color: Theme.palette.baseColor4
    radius: 8

    ColumnLayout {
        id: layout
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        StatusListItem {
            objectName: "walletKeyPairDelegate"
            Layout.fillWidth: true
            title: !!root.keyPair? d.isWatchOnly ? qsTr("Watched addresses") : root.keyPair.name : ""
            statusListItemSubTitle.textFormat: Qt.RichText
            titleTextIcon: !!root.keyPair && keyPair.migratedToKeycard ? "keycard": ""
            subTitle: Utils.getKeypairLocation(root.keyPair, false)
            statusListItemSubTitle.color: Utils.getKeypairLocationColor(Theme.palette, root.keyPair)
            color: StatusColors.transparent
            asset {
                width: !!root.keyPair && keyPair.icon? root.Theme.bigPadding : 40
                height: !!root.keyPair && keyPair.icon? root.Theme.bigPadding : 40
                name: !root.keyPair? ""
                                   : !!root.keyPair.image? root.keyPair.image
                                                         : !!root.keyPair.icon? root.keyPair.icon
                                                                              : d.isProfileKeypair? "contact"
                                                                                                  : ""
                isImage: !!root.keyPair && !!keyPair.image
                color: d.isProfileKeypair ? Theme.palette.indirectColor2
                                          : Theme.palette.primaryColor1
                letterSize: Math.max(4, asset.width / 2.4)
                charactersLen: 2
                isLetterIdenticon: !!root.keyPair && !keyPair.icon && !asset.name.toString()
                bgColor: d.isProfileKeypair? Utils.colorForPubkey(Theme.palette, root.userProfilePublicKey)
                                           : Theme.palette.primaryColor3
            }
            components: [
                StatusFlatRoundButton {
                    icon.name: "more"
                    icon.color: Theme.palette.directColor1
                    visible: !d.isWatchOnly
                    highlighted: menuLoader.item && menuLoader.item.opened
                    onClicked: {
                        menuLoader.active = true
                        menuLoader.item.popup(0, height)
                    }

                    Loader {
                        id: menuLoader
                        active: false
                        sourceComponent: WalletKeypairAccountMenu {
                            onClosed: {
                                menuLoader.active = false
                            }
                            keyPair: root.keyPair
                            hasPairedDevices: root.hasPairedDevices
                            onRunExportQrFlow: root.runExportQrFlow()
                            onRunImportViaQrFlow: root.runImportViaQrFlow()
                            onRunImportViaSeedPhraseFlow: root.runImportViaSeedPhraseFlow()
                            onRunImportViaPrivateKeyFlow: root.runImportViaPrivateKeyFlow()
                            onRunRenameKeypairFlow: root.runRenameKeypairFlow()
                            onRunRemoveKeypairFlow: root.runRemoveKeypairFlow()
                            onRunMoveKeypairToKeycardFlow: root.runMoveKeypairToKeycardFlow()
                            onRunStopUsingKeycardFlow: root.runStopUsingKeycardFlow()
                        }
                    }
                }
            ]
        }
        StatusListView {
            Layout.fillWidth: true
            Layout.preferredHeight: childrenRect.height
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 1
            model: d.relatedAccounts
            delegate: WalletAccountDelegate {
                id: walletAccountDelegate
                width: ListView.view.width
                account: model.account
                totalCount: ListView.view.count
                compIndex: index
                onGoToAccountView: root.goToAccountView(model.account)

                RowLayout {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.padding + walletAccountDelegate.statusListItemComponentsSlot.width
                    visible: keyPair.pairType === Constants.keypair.type.watchOnly

                    StatusIcon {
                        icon: "wallet"
                        color: Theme.palette.baseColor1
                    }
                    StatusBaseText {
                        text: model.account.hideFromTotalBalance ? qsTr("Excluded") : qsTr("Included")
                        color: Theme.palette.baseColor1
                    }
                }
            }
        }
    }
}
