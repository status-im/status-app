import QtQuick
import QtQuick.Layouts

import StatusQ
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Popups

import AppLayouts.Communities.controls
import AppLayouts.Communities.helpers
import AppLayouts.Communities.panels
import AppLayouts.Wallet.controls
import utils

import shared.controls

import SortFilterProxyModel

StatusScrollView {
    id: root

    property int preferredContentWidth: width
    property int internalRightPadding: 0

    // Community info:
    property string communityName
    property url communityLogo
    property color communityColor

    // Network related properties:
    property var flatNetworks

    // Wallet account expected roles: address, name, color, emoji, walletType
    property var accounts

    property string feeText
    property string feeErrorText
    property bool isFeeLoading

    // Privileged tokens:
    readonly property TokenObject ownerToken: TokenObject {
        name: PermissionsHelpers.ownerTokenNameTag + root.communityName
        type: Constants.TokenType.ERC721
        privilegesLevel: Constants.TokenPrivilegesLevel.Owner
        artworkSource: root.communityLogo
        color: root.communityColor
        symbol: PermissionsHelpers.communityNameToSymbol(true, root.communityName)
        transferable: true
        remotelyDestruct: false
        supply: "1"
        infiniteSupply: false
        description: qsTr("This is the %1 Owner token. The hodler of this collectible has ultimate control over %1 Community token administration.").arg(root.communityName)
    }
    readonly property TokenObject tMasterToken: TokenObject {
        name: PermissionsHelpers.tMasterTokenNameTag + root.communityName
        type: Constants.TokenType.ERC721
        privilegesLevel: Constants.TokenPrivilegesLevel.TMaster
        artworkSource: root.communityLogo
        color: root.communityColor
        symbol: PermissionsHelpers.communityNameToSymbol(false, root.communityName)
        remotelyDestruct: true
        description: qsTr("This is the %1 TokenMaster token. The hodler of this collectible has full admin rights for the %1 Community in Status and can mint and airdrop %1 Community tokens.").arg(root.communityName)
    }

    readonly property string feeLabel:
        qsTr("Mint %1 Owner and TokenMaster tokens on %2")
        .arg(communityName).arg(ownerToken.chainName)

    signal mintClicked

    QtObject {
        id: d

        readonly property int titleSize: 17
        readonly property int iconSize: 20
    }

    padding: 0
    contentWidth: mainLayout.width
    contentHeight: mainLayout.height

    ColumnLayout {
        id: mainLayout

        width: root.availableWidth
        spacing: Theme.padding

        // Owner token defintion:
        StatusBaseText {
            Layout.fillWidth: true
            Layout.maximumWidth: root.preferredContentWidth
            Layout.rightMargin: root.internalRightPadding

            elide: Text.ElideMiddle
            font.pixelSize: d.titleSize
            font.bold: true

            text: ownerToken.name
        }

        TokenInfoPanel {
            Layout.fillWidth: true
            Layout.maximumWidth: root.preferredContentWidth
            Layout.rightMargin: root.internalRightPadding

            token: root.ownerToken
            accountBoxVisible: false
            networkBoxVisible: false
        }

        StatusModalDivider {
            Layout.fillWidth: true
            Layout.maximumWidth: root.preferredContentWidth
            Layout.rightMargin: root.internalRightPadding

            topPadding: Theme.padding
            bottomPadding: Theme.padding
        }

        // TMaster token definition:
        StatusBaseText {

            Layout.fillWidth: true
            Layout.maximumWidth: root.preferredContentWidth
            Layout.rightMargin: root.internalRightPadding

            elide: Text.ElideMiddle
            font.pixelSize: d.titleSize
            font.bold: true

            text: tMasterToken.name
        }

        TokenInfoPanel {
            Layout.fillWidth: true
            Layout.maximumWidth: root.preferredContentWidth
            Layout.rightMargin: root.internalRightPadding

            token: root.tMasterToken
            accountBoxVisible: false
            networkBoxVisible: false
        }

        StatusModalDivider {
            Layout.fillWidth: true
            Layout.maximumWidth: root.preferredContentWidth
            Layout.rightMargin: root.internalRightPadding

            topPadding: Theme.padding
            bottomPadding: Theme.padding
        }

        CustomLabelDescriptionComponent {
            Layout.maximumWidth: root.preferredContentWidth
            Layout.rightMargin: root.internalRightPadding

            label: qsTr("Select account")
            description: qsTr("This account will be where you receive your Owner token and will also be the account that pays the token minting gas fees.")
        }

        ColumnLayout {
            spacing: 11

            Layout.maximumWidth: root.preferredContentWidth
            Layout.rightMargin: root.internalRightPadding

            AccountSelector {
                id: accountBox

                Layout.fillWidth: true
                Layout.topMargin: -Theme.halfPadding
                model: root.accounts
                selectedAddress: ownerToken.accountAddress

                Binding {
                    target: root.ownerToken
                    property: "accountAddress"
                    value: accountBox.currentAccountAddress
                }

                Binding {
                    target: root.ownerToken
                    property: "accountName"
                    value: accountBox.currentAccount.name
                }

                Binding {
                    target: root.tMasterToken
                    property: "accountAddress"
                    value: accountBox.currentAccountAddress
                }

                Binding {
                    target: root.tMasterToken
                    property: "accountName"
                    value: accountBox.currentAccount.name
                }
            }

            StatusBaseText {
                Layout.fillWidth: true

                visible: !!root.feeErrorText
                horizontalAlignment: Text.AlignRight

                font.pixelSize: Theme.tertiaryTextFontSize
                color: Theme.palette.dangerColor1
                text: root.feeErrorText
                wrapMode: Text.Wrap
            }
        }

        CustomNetworkFilterRowComponent {
            id: networkSelector

            Layout.maximumWidth: root.preferredContentWidth
            Layout.rightMargin: root.internalRightPadding

            label: qsTr("Select network")
            description: qsTr("The network you select will be where all your community’s tokens reside. Once set, this setting can’t be changed and tokens can’t move to other networks.")
        }

        FeesBox {
            Layout.fillWidth: true
            Layout.maximumWidth: root.preferredContentWidth
            Layout.rightMargin: root.internalRightPadding

            Layout.topMargin: Theme.padding

            model: QtObject {
                id: singleFeeModel

                readonly property string title: root.feeLabel
                readonly property string feeText: root.isFeeLoading ?
                                                      "" : root.feeText
                readonly property bool error: root.feeErrorText !== ""
            }

            showAccountsSelector: false
        }

        StatusButton {
            Layout.preferredHeight: 44
            Layout.maximumWidth: root.preferredContentWidth
            Layout.fillWidth: true

            Layout.rightMargin: root.internalRightPadding
            Layout.topMargin: 4
            Layout.bottomMargin: Theme.padding

            enabled: root.feeText && !root.feeErrorText
            objectName: "mintButton"
            text: qsTr("Mint")

            onClicked: root.mintClicked()
        }
    }

    component CustomLabelDescriptionComponent: ColumnLayout {
        id: labelDescComponent

        property string label
        property string description

        Layout.fillWidth: true

        StatusBaseText {
            text: labelDescComponent.label
            color: Theme.palette.directColor1
            font.pixelSize: Theme.primaryTextFontSize
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: labelDescComponent.description
            color: Theme.palette.baseColor1
            font.pixelSize: Theme.primaryTextFontSize
            lineHeight: 1.2
            wrapMode: Text.WordWrap
        }
    }

    component CustomNetworkFilterRowComponent: ColumnLayout {
        id: networkComponent

        property string label
        property string description

        Layout.topMargin: Theme.padding
        spacing: 8

        CustomLabelDescriptionComponent {
            label: networkComponent.label
            description: networkComponent.description
        }

        NetworkFilter {
            id: netFilter
            objectName: "netFilter"

            Layout.fillWidth: true

            flatNetworks: root.flatNetworks
            disableChainsWithNoCommunitiesSupport: true
            selection: !!ownerToken.chainId ? [ownerToken.chainId] : [SQUtils.ModelUtils.getByKey(flatNetworks, "layer", 2).chainId/*first layer 2 network*/]

            multiSelection: false
            control.topPadding: 14
            control.background.height: 50
            
            onToggleNetwork: {
                // Set Owner Token network properties:
                ownerToken.chainId = singleSelectionItemData.chainId
                ownerToken.chainName = singleSelectionItemData.chainName
                ownerToken.chainIcon = singleSelectionItemData.iconUrl

                // Set TMaster Token network properties:
                tMasterToken.chainId = singleSelectionItemData.chainId
                tMasterToken.chainName = singleSelectionItemData.chainName
                tMasterToken.chainIcon = singleSelectionItemData.iconUrl
            }
        }
    }
}
