import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups
import StatusQ.Popups.Dialog
import StatusQ.Core.Utils
import StatusQ.Components

import shared.popups
import AppLayouts.Wallet.stores as WalletStores

import utils

StatusDialog {
    id: root

    // Community related props:
    property string communityId
    property string communityName
    property string communityLogo

    // Transaction related props:
    property var token // Expected roles: accountAddress, key, chainId, name, artworkSource

    signal cancelClicked
    signal transferOwnershipRequested(string tokenId, string senderAddress, string tokenName, string tokenImage)

    width: 640 // by design
    padding: Theme.padding
    contentItem: ColumnLayout {
        spacing: Theme.bigPadding

        component CustomText : StatusBaseText {
            Layout.fillWidth: true

            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            font.pixelSize: Theme.primaryTextFontSize
            color: Theme.palette.directColor1
        }

        CustomText {
            Layout.topMargin: Theme.halfPadding

            text: qsTr("Are you sure you want to transfer ownership of %1? All ownership rights you currently hold for %1 will be transferred to the new owner.").arg(root.communityName)
        }

        CustomText {
            text: qsTr("To transfer ownership of %1:").arg(root.communityName)
            font.bold: true
        }

        CustomText {
            text: qsTr("1. Send the %1 Owner token (%2) to the new owner’s address").arg(root.communityName).arg(token.name)
        }

        CustomText {
            text: qsTr("2. Ask the new owner to setup the control node for %1 on their desktop device").arg(root.communityName)
        }

        StatusMenuSeparator {
            Layout.fillWidth: true
        }

        CustomText {
            text: qsTr("I acknowledge that...")
        }

        StatusCheckBox {
            id: ackCheckBox

            Layout.topMargin: -Theme.halfPadding
            Layout.bottomMargin: Theme.halfPadding

            font.pixelSize: Theme.primaryTextFontSize
            text: qsTr("My ownership rights will be removed and transferred to the recipient")
        }
    }

    header: StatusDialogHeader {
        headline.title: qsTr("Transfer ownership of %1").arg(root.communityName)
        actions.closeButton.onClicked: root.close()
        leftComponent: StatusSmartIdenticon {
            asset.name: root.communityLogo
            asset.isImage: !!asset.name
        }
    }

    footer: StatusDialogFooter {
        spacing: Theme.padding
        rightButtons: ObjectModel {
            StatusFlatButton {
                text: qsTr("Cancel")

                onClicked: {
                    root.cancelClicked()
                    close()
                }
            }

            StatusButton {
                enabled: ackCheckBox.checked
                text: qsTr("Send %1 owner token").arg(root.communityName)
                type: StatusBaseButton.Type.Danger

                onClicked: {
                    // Pre-populated dialog with the relevant Owner token info:
                    const store = WalletStores.RootStore.currentActivityFiltersStore
                    const uid = store.collectiblesList.getUidForData("0", token.tokenAddress.toLowerCase(), token.chainId);
                    // Pass the token display data along: a freshly minted owner token may not be indexed in the wallet's owned collectibles yet
                    root.transferOwnershipRequested(uid, token.accountAddress.toLowerCase(), token.name ?? "", token.artworkSource ?? "")
                    close()
                }
            }
        }
    }
}
