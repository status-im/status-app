import QtQuick
import QtQuick.Layouts

import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Core

import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.Wallet.panels
import AppLayouts.Market.controls

import shared.stores as SharedStores
import utils

RightTabBaseView {
    id: root

    signal sendToAddressRequested(string address)

    required property WalletStores.RootStore rootStore
    required property var contactsStore
    required property SharedStores.NetworkConnectionStore networkConnectionStore
    required property SharedStores.NetworksStore networksStore

    header: WalletFollowingAddressesHeader {
        id: followingHeader
        accountsModel: root.rootStore.nonWatchAccounts
        lastReloadedTime: !!root.rootStore.lastReloadTimestamp ?
                              LocaleUtils.formatRelativeTimestamp(
                                  root.rootStore.lastReloadTimestamp * 1000) : ""
        loading: followingAddresses.isPaginationLoading

        onReloadRequested: followingAddresses.refresh()
        onAddViaEFPClicked: Global.requestOpenLink("https://efp.app")
        onAccountChanged: (address) => followingAddresses.refresh(address)
    }

    Item {
        anchors.fill: parent

        FollowingAddresses {
            id: followingAddresses
            objectName: "followingAddressesArea"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: paginationFooter.visible ? paginationFooter.top : parent.bottom

            contactsStore: root.contactsStore
            networkConnectionStore: root.networkConnectionStore
            networksStore: root.networksStore
            followingAddressesModel: root.rootStore.followingAddresses
            totalFollowingCount: walletSectionFollowingAddresses ? 
                                 walletSectionFollowingAddresses.totalFollowingCount : 0
            rootStore: root.rootStore
            selectedAddress: followingHeader.selectedAddress

            onSendToAddressRequested: root.sendToAddressRequested(address)
            
            onRefreshRequested: (address, search, limit, offset) => {
                root.rootStore.refreshFollowingAddresses(address, search, limit, offset)
            }
            
            Connections {
                target: walletSectionFollowingAddresses
                function onFollowingAddressesUpdated() {
                    followingAddresses.followingAddressesUpdated()
                }
            }
        }

        // Full-width divider above pagination (extends beyond content padding)
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: -(Theme.xlPadding * 2)
            anchors.rightMargin: -(Theme.xlPadding * 2)
            anchors.bottom: paginationFooter.top
            height: 1
            color: Theme.palette.baseColor2
            visible: paginationFooter.visible
        }

        // Sticky pagination footer at bottom (extends beyond content padding)
        Paginator {
            id: paginationFooter
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -(Theme.halfPadding + 2)
            topPadding: Theme.padding
            bottomPadding: Theme.padding
            visible: followingAddresses.showPagination
            
            pageSize: followingAddresses.pageSize
            totalCount: followingAddresses.totalCount
            currentPage: followingAddresses.currentPage
            enabled: !followingAddresses.isPaginationLoading
            onRequestPage: followingAddresses.goToPage(pageNumber)
        }
    }
}
