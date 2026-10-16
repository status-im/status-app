import QtQuick
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Utils as StatusQUtils

import utils
import shared.panels

import AppLayouts.Communities.helpers
import AppLayouts.Communities.panels

import QtModelsToolkit

StatusScrollView {
    id: root

    property int preferredContentWidth: width
    property int internalRightPadding: 0

    property bool preview: false

    // https://bugreports.qt.io/browse/QTBUG-84269
    /* required */ property TokenObject token
    /* required */ property string feeText
    /* required */ property string feeErrorText
    /* required */ property bool isFeeLoading


    readonly property bool isAssetView: token.type === Constants.TokenType.ERC20

    readonly property string name: token.name
    readonly property string description: token.description
    readonly property string symbol: token.symbol
    readonly property int supply: token.supply
    readonly property url artworkSource: token.artworkSource
    readonly property rect artworkCropRect: token.artworkCropRect
    readonly property bool infiniteSupply: token.infiniteSupply
    readonly property int remainingTokens: root.preview ? root.supply : token.remainingTokens
    readonly property int deployState: token.deployState
    readonly property string accountName: token.accountName
    readonly property string chainName: token.chainName
    readonly property string chainId: token.chainId
    readonly property string accountAddress: token.accountAddress
    readonly property bool remotelyDestruct: token.remotelyDestruct
    readonly property int remotelyDestructState: token.remotelyDestructState
    readonly property bool transferable: token.transferable
    readonly property string chainIcon: token.chainIcon
    readonly property int decimals: token.decimals
    readonly property int multiplierIndex: token.multiplierIndex

    readonly property bool deploymentCompleted:
        deployState === Constants.ContractTransactionStatus.Completed

    readonly property string feeLabel:
        isAssetView ? qsTr("Mint asset on %1").arg(token.chainName)
                    : qsTr("Mint collectible on %1").arg(token.chainName)
                    
    // Models:
    property var tokenOwnersModel
    property var membersModel

    // Required for preview mode:
    property var accounts
    signal mintClicked()

    signal airdropRequested(string address)
    signal generalAirdropRequested

    signal viewProfileRequested(string contactId)
    signal viewMessagesRequested(string contactId)

    signal remoteDestructRequested(string name, string address)
    signal kickRequested(string name, string contactId, string address)
    signal banRequested(string name, string contactId, string address)

    signal startTokenHoldersManagement(int chainId, string address)
    signal stopTokenHoldersManagement()

    onVisibleChanged: {
        if (visible) {
            root.startTokenHoldersManagement(root.chainId, root.token.tokenAddress)
        } else {
            root.stopTokenHoldersManagement()
        }
    }

    Component.onCompleted: root.startTokenHoldersManagement(root.chainId, root.token.tokenAddress)
    Component.onDestruction: root.stopTokenHoldersManagement()

    QtObject {
        id: d

        readonly property int iconSize: 20
        property bool loadingTokenHolders: false

        readonly property var renamedTokenOwnersModel: RolesRenamingModel {
            sourceModel: root.tokenOwnersModel
            mapping: [
                RoleRename {
                    from: "contactId"
                    to: "pubKey"
                }
            ]
        }

        readonly property LeftJoinModel joinModel: LeftJoinModel {
            leftModel: d.renamedTokenOwnersModel
            rightModel: root.membersModel

            joinRole: "pubKey"
        }
    }

    padding: 0
    contentWidth: mainLayout.width
    contentHeight: mainLayout.height

    ColumnLayout {
        id: mainLayout

        width: Math.min(root.preferredContentWidth,
                        root.availableWidth - root.internalRightPadding)

        spacing: Theme.padding

        RowLayout {
            visible: !root.preview && !root.deploymentCompleted
            spacing: Theme.halfPadding

            StatusDotsLoadingIndicator { visible: (root.deployState === Constants.ContractTransactionStatus.InProgress) }

            StatusIcon {
                visible: (root.deployState === Constants.ContractTransactionStatus.Failed)
                icon: "warning"
                color: Theme.palette.dangerColor1
            }

            StatusBaseText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                wrapMode: Text.Wrap
                maximumLineCount: 3
                font.pixelSize: Theme.primaryTextFontSize
                text: (root.deployState === Constants.ContractTransactionStatus.InProgress) ?
                          (root.isAssetView ?
                               qsTr("Asset is being minted") : qsTr("Collectible is being minted")) :
                          (root.deployState === Constants.ContractTransactionStatus.Failed) ?
                              (root.isAssetView ? qsTr("Asset minting failed") : qsTr("Collectible minting failed")) : ""
                color: (root.deployState === Constants.ContractTransactionStatus.Failed) ? Theme.palette.dangerColor1 : Theme.palette.directColor1
            }
        }

        TokenInfoPanel {
            Layout.fillWidth: true

            token: root.token
        }

        RowLayout {
            visible: root.preview
            Layout.fillWidth: true

            StatusIcon {
                Layout.preferredWidth: d.iconSize
                Layout.preferredHeight: d.iconSize
                Layout.alignment: Qt.AlignTop
                color: Theme.palette.baseColor1
                icon: "info"
            }

            StatusBaseText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.pixelSize: Theme.primaryTextFontSize
                color: Theme.palette.baseColor1
                text: qsTr("Review token details before minting it as they can't be edited later")
            }
        }

        FeesBox {
            id: feesBox

            Layout.fillWidth: true
            Layout.topMargin: Theme.padding

            implicitWidth: 0
            visible: root.preview

            accountErrorText: root.feeErrorText

            model: QtObject {
                readonly property string title: root.feeLabel
                readonly property string feeText: root.isFeeLoading ?
                                                      "" : root.feeText
                readonly property bool error: root.feeErrorText !== ""
            }

            accountsSelector.model: root.accounts || null
            accountsSelector.selectedAddress: root.token.accountAddress

            Binding {
                target: root.token
                property: "accountAddress"
                value: feesBox.accountsSelector.currentAccountAddress
            }

            Binding {
                target: root.token
                property: "accountName"
                value: feesBox.accountsSelector.currentAccount.name
            }
        }

        StatusButton {
            objectName: "communityTokenMintButton"
            Layout.preferredHeight: 44
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.topMargin: Theme.halfPadding

            visible: root.preview
            enabled: !root.isFeeLoading && root.feeErrorText === ""

            text: qsTr("Mint")

            onClicked: root.mintClicked()
        }

        Loader {
            id: tokenHolderLoader

            Layout.fillWidth: true

            visible: !root.preview && root.deploymentCompleted
            sourceComponent: token.tokenHoldersLoading ? tokenHoldersLoadingComponent
                                                       : sortableTokenHolderPanel
        }

        Component {
            id: tokenHoldersLoadingComponent

            StatusBaseText {
                text: qsTr("Loading token holders...")

                wrapMode: Text.Wrap
            }
        }

        Component {
            id: sortableTokenHolderPanel

            SortableTokenHoldersPanel {
                model: d.joinModel
                tokenName: root.name
                showRemotelyDestructMenuItem: !root.isAssetView && root.remotelyDestruct
                isAirdropEnabled: root.deploymentCompleted &&
                                (token.infiniteSupply || token.remainingTokens > 0)
                multiplierIndex: root.multiplierIndex

                Layout.topMargin: Theme.padding
                Layout.fillWidth: true

                onViewProfileRequested: root.viewProfileRequested(contactId)
                onViewMessagesRequested: root.viewMessagesRequested(contactId)
                onAirdropRequested: root.airdropRequested(address)
                onGeneralAirdropRequested: root.generalAirdropRequested()
                onRemoteDestructRequested: root.remoteDestructRequested(name, address)

                onKickRequested: root.kickRequested(name, contactId, address)
                onBanRequested: root.banRequested(name, contactId, address)
            }
        }
    }
}
