import QtQuick
import QtQuick.Layouts

import QtModelsToolkit
import SortFilterProxyModel

import StatusQ
import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Utils as StatusQUtils

import AppLayouts.Communities.panels
import AppLayouts.Communities.stores

import utils
import shared.controls
import shared.views
import shared.popups
import shared.stores as SharedStores

import AppLayouts.Wallet.stores

import "../../controls"

Item {
    id: root

    required property SharedStores.RootStore rootStore
    required property RootStore walletRootStore
    required property CommunitiesStore communitiesStore
    required property SharedStores.NetworksStore networksStore

    required property var collectible
    property var activityModel
    property bool isCollectibleLoading
    required property string addressFilters

    // Community related token props:
    readonly property bool isCommunityCollectible: !!collectible ? collectible.communityId !== "" : false
    readonly property bool isOwnerTokenType: !!collectible ? (collectible.communityPrivilegesLevel === Constants.TokenPrivilegesLevel.Owner) : false
    readonly property bool isTMasterTokenType: !!collectible ? (collectible.communityPrivilegesLevel === Constants.TokenPrivilegesLevel.TMaster) : false

    readonly property var communityDetails: isCommunityCollectible ? root.communitiesStore.getCommunityDetailsAsJson(collectible.communityId) : null

    QtObject {
        id: d
        readonly property string collectibleLink: !!collectible ? root.walletRootStore.getOpenSeaCollectibleUrl(collectible.networkShortName, collectible.contractAddress, collectible.tokenId): ""
        readonly property string collectionLink: !!collectible ? root.walletRootStore.getOpenSeaCollectionUrl(collectible.networkShortName, collectible.contractAddress): ""
        readonly property string blockExplorerLink: !!collectible ? root.walletRootStore.getExplorerUrl(collectible.networkShortName, collectible.contractAddress, collectible.tokenId): ""
        readonly property var addrFilters: root.addressFilters.split(":").map((addr) => addr.toLowerCase())
        readonly property int imageStackSpacing: 4
        readonly property bool activityLoading: walletRootStore.tmpActivityController0.status.loadingData

        property Component balanceTag: Component {
            CollectibleBalanceTag {
                balance: d.balanceAggregator.value
            }
        }
        property SortFilterProxyModel filteredBalances: SortFilterProxyModel {
            sourceModel: !!collectible ? collectible.ownership : null
            filters: [
                FastExpressionFilter {
                    expression: {
                        d.addrFilters
                        return d.addrFilters.includes(model.accountAddress.toLowerCase())
                    }
                    expectedRoles: ["accountAddress"]
                }
            ]
        }

        property SumAggregator balanceAggregator: SumAggregator {
            model: d.filteredBalances
            roleName: "balance"
        }

        function getCurrentTab() {
            for (let i =0; i< collectiblesDetailsTab.contentChildren.length; i++) {
                if(collectiblesDetailsTab.contentChildren[i].visible) {
                    return i
                }
            }
            return 0
        }
    }

    CollectibleDetailsHeader {
        id: collectibleHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        collectibleName: !!collectible && !!collectible.name ? collectible.name : qsTr("Unknown")
        collectibleId: !!collectible ? "#" + collectible.tokenId : ""
        communityName: !!communityDetails ? communityDetails.name : ""
        communityId: !!collectible ? collectible.communityId : ""
        collectionName: !!collectible ? collectible.collectionName : ""
        communityImage: !!communityDetails ? communityDetails.image : ""
        networkShortName: !!collectible ? collectible.networkShortName : ""
        networkColor: !!collectible ?collectible.networkColor : ""
        networkIconURL: !!collectible ? collectible.networkIconUrl : ""
        networkExplorerName: !!collectible ? Utils.getChainExplorerName(collectible.networkShortName): ""
        collectibleLinkEnabled: Utils.getUrlStatus(d.collectibleLink)
        collectionLinkEnabled: (!!communityDetails && communityDetails.name)  || Utils.getUrlStatus(d.collectionLink)
        explorerLinkEnabled: Utils.getUrlStatus(d.blockExplorerLink)
        onCollectionTagClicked: {
            if (root.isCommunityCollectible) {
                Global.switchToCommunity(collectible.communityId)
            }
            else {
                Global.requestOpenLink(d.collectionLink)
            }
        }
        onOpenCollectibleExternally: Global.requestOpenLink(d.collectibleLink)
        onOpenCollectibleOnExplorer: Global.requestOpenLink(d.blockExplorerLink)
    }

    ColumnLayout {
        id: collectibleBody
        anchors.top: collectibleHeader.bottom
        anchors.topMargin: 25
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        spacing: Theme.padding

        Row {
            id: collectibleImageDetails

            readonly property real visibleImageHeight: artwork.height
            readonly property real visibleImageWidth: artwork.width

            Layout.preferredHeight: collectibleImageDetails.visibleImageHeight
            Layout.fillWidth: true
            spacing: 24

            ColumnLayout {
                id: artwork
                spacing: 0
                Repeater {
                    id: repeater
                    model: Math.min(3, d.balanceAggregator.value)
                    Item {
                        Layout.preferredWidth: childrenRect.width
                        Layout.preferredHeight: childrenRect.height
                        Layout.leftMargin: index * d.imageStackSpacing
                        Layout.topMargin: index === 0 ? 0 : -Layout.preferredHeight + d.imageStackSpacing
                        opacity: index === 0 ? 1: 0.4/index
                        // so that the first item remains on top in the stack
                        z: -index
                        Loader {
                            property int modelIndex: index
                            anchors.top: parent.top
                            anchors.left: parent.left
                            sourceComponent: root.isCollectibleLoading ?
                                                 collectibleimageComponent:
                                                 root.isCommunityCollectible && (root.isOwnerTokenType || root.isTMasterTokenType) ?
                                                     privilegedCollectibleImageComponent:
                                                     collectibleimageComponent
                            active: root.visible
                        }
                        Loader {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: Theme.padding
                            sourceComponent: d.balanceTag
                            // only show balance tag on top of the first image in stack
                            active: index === 0 && d.balanceAggregator.value > 1 && root.visible
                        }
                    }
                }
            }

            Column {
                id: collectibleNameAndDescription
                spacing: 12

                width: parent.width - collectibleImageDetails.visibleImageWidth - Theme.bigPadding

                StatusBaseText {
                    id: collectibleName
                    width: parent.width
                    height: 24

                    text: root.isCommunityCollectible && !!communityDetails ? qsTr("Minted by %1").arg(root.communityDetails.name):
                                                                              !!collectible ? collectible.collectionName: ""
                    color: Theme.palette.directColor1
                    font.pixelSize: Theme.secondaryAdditionalTextSize
                    lineHeight: 24
                    lineHeightMode: Text.FixedHeight
                    elide: Text.ElideRight
                    wrapMode: Text.WordWrap
                }

                StatusBaseText {
                    id: descriptionText
                    width: parent.width
                    height: collectibleImageDetails.height - collectibleName.height - parent.spacing

                    clip: true
                    text: !!collectible ? collectible.description : ""
                    textFormat: Text.MarkdownText
                    color: Theme.palette.directColor4
                    lineHeight: 22
                    lineHeightMode: Text.FixedHeight
                    elide: Text.ElideRight
                    wrapMode: Text.Wrap
                }
            }
        }

        StatusTabBar {
            id: collectiblesDetailsTab
            Layout.fillWidth: true
            topPadding: 52

            currentIndex: d.getCurrentTab()

            StatusTabButton {
                text: qsTr("Properties")
                width: visible ? implicitWidth: 0
                visible: root.isCommunityCollectible
                enabled: visible
            }

            StatusTabButton {
                text: qsTr("Traits")
                width: visible ? implicitWidth: 0
                visible: !root.isCommunityCollectible && !!collectible && collectible.traits.count > 0
                enabled: visible
            }

            StatusTabButton {
                text: qsTr("Links")
                width: visible ? implicitWidth: 0
                visible: !root.isCommunityCollectible && (!!collectible &&
                                                          ((!!collectible.website && !!collectible.collectionName) ||
                                                          collectible.twitterHandle))
                enabled: visible
            }
        }

        StatusScrollView {
            id: scrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            padding: 0

            Loader {
                id: tabLoader
                width: scrollView.availableWidth
                sourceComponent: {
                    switch (collectiblesDetailsTab.currentIndex) {
                    case 0: return traitsView
                    case 1: return traitsView
                    case 2: return linksView
                    }
                }

                Component {
                    id: traitsView
                    Flow {
                        spacing: 10
                        Repeater {
                            model: !!collectible ? collectible.traits: null
                            InformationTile {
                                width: Math.min(implicitWidth, parent.width)
                                primaryText: model.traitType
                                secondaryText: model.value
                            }
                        }
                    }
                }

                Component {
                    id: activityView
                    StatusListView {
                        height: scrollView.availableHeight
                        model: root.activityModel
                        header: ShapeRectangle {
                            width: parent.width
                            height: visible ? 42: 0
                            visible: !root.activityModel.count && !d.activityLoading
                            font.pixelSize: Theme.primaryTextFontSize
                            text: qsTr("Activity will appear here")
                        }
                        delegate: TransactionDelegate {
                            required property var model
                            required property int index
                            width: ListView.view.width
                            modelData: model.activityEntry
                            timeStampText: isModelDataValid ? LocaleUtils.formatRelativeTimestamp(modelData.timestamp * 1000, true) : ""
                            flatNetworks: root.networksStore.allNetworks
                            currenciesStore: root.rootStore.currencyStore
                            activityStore: root.walletRootStore
                            showAllAccounts: root.walletRootStore.showAllAccounts
                            displayValues: true
                            community: isModelDataValid && !!communityId && !!root.communitiesStore ? root.communitiesStore.getCommunityDetailsAsJson(communityId) : null
                            loading: false
                            onClicked: {
                                if (mouse.button === Qt.RightButton) {
                                    // TODO: Implement context menu
                                }
                            }
                        }
                    }
                }

                Component {
                    id: linksView
                    Flow {
                        spacing: 10
                        CollectibleLinksTags {
                            asset.name: !!collectible ? collectible.collectionImageUrl: ""
                            asset.isImage: true
                            primaryText: !!collectible ? collectible.collectionName : ""
                            secondaryText: !!collectible ? collectible.website : ""
                            visible: !!collectible && !!collectible.website && !!collectible.collectionName
                            enabled: !!collectible ? Utils.getUrlStatus(collectible.website): false
                            onClicked: Global.requestOpenLink(collectible.website)
                        }
                        CollectibleLinksTags {
                            asset.name: "tiny/opensea"
                            primaryText: qsTr("Opensea")
                            secondaryText: d.collectionLink
                            visible: Utils.getUrlStatus(d.collectionLink)
                            onClicked: Global.requestOpenLink(d.collectionLink)
                        }
                        CollectibleLinksTags {
                            asset.name: "xtwitter"
                            primaryText: qsTr("Twitter")
                            secondaryText: !!collectible ? collectible.twitterHandle : ""
                            visible: !!collectible && collectible.twitterHandle
                            onClicked: Global.requestOpenLink(root.walletRootStore.getTwitterLink(collectible.twitterHandle))
                        }
                    }
                }
            }
        }
    }
    Component {
        id: privilegedCollectibleImageComponent
        // Special artwork representation for community `Owner and Master Token` token types:
        PrivilegedTokenArtworkPanel {
            size: PrivilegedTokenArtworkPanel.Size.Large
            artwork: collectible.imageUrl ?? ""
            color: !!root.collectible && !!root.communityDetails ? root.communityDetails.color : "transparent"
            isOwner: root.isOwnerTokenType
        }
    }

    Component {
        id: collectibleimageComponent
        CollectibleMedia {
            id: collectibleImage
            backgroundColor: collectible.backgroundColor ? collectible.backgroundColor : Theme.palette.baseColor5
            isCollectibleLoading: root.isCollectibleLoading
            mediaUrl: collectible.mediaUrl ?? ""
            mediaType: !!collectible ? (modelIndex > 0 && collectible.mediaType.startsWith("video")) ? "" : collectible.mediaType: ""
            fallbackImageUrl: collectible.imageUrl
            manualMaxDimension: 240
            interactive: !isError && !isEmpty
            enabled: interactive
            onImageClicked: (image, plain) => Global.openImagePopup(image, "", plain)
            onVideoClicked: (url) => Global.openVideoPopup(url)
            onOpenImageContextMenu: (url, isGif, x, y) => imageContextMenu.createObject(this, { imageSource: url, isGif: isGif, isVideo: false }).popup(x, y)
            onOpenVideoContextMenu: (url, x, y) => imageContextMenu.createObject(this, { imageSource: url, url: url, isVideo: true, isGif: false }).popup(x, y)
        }
    }

    Component {
        id: imageContextMenu
        ImageContextMenu {
            onClosed: destroy()
        }
    }
}
