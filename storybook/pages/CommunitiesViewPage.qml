import QtQuick
import QtQuick.Controls

import StatusQ
import StatusQ.Core

import AppLayouts.stores as AppLayoutsStores
import AppLayouts.Profile.views
import AppLayouts.Wallet.stores
import AppLayouts.Profile.stores
import mainui
import utils

import shared.stores as SharedStores

import Storybook
import Models
import Mocks

SplitView {
    id: root

    Logs { id: logs }

    orientation: Qt.Vertical

    readonly property WalletAssetsStoreMock walletAssetStore: WalletAssetsStoreMock {
    }

    readonly property var currencyStore: SharedStores.CurrenciesStore {}

    Keychain {
        id: popupsKeychain
    }

    Popups {
        keychain: popupsKeychain
        popupParent: root
        sharedRootStore: SharedStores.RootStore {}
        rootStore: AppLayoutsStores.RootStore
        communityTokensStore: SharedStores.CommunityTokensStore {}
        networksStore: SharedStores.NetworksStore {}
    }

    ListModel {
        id: emptyModel
    }

    CommunitiesModel {
        id: communitiesModel
    }

    CommunitiesView {
        SplitView.fillWidth: true
        SplitView.preferredHeight: 400

        contentWidth: 664

        communitiesList: ctrlEmptyView.checked ? emptyModel : communitiesModel
        rootStore: AppLayoutsStores.RootStore {
            function setActiveCommunity(communityId) {
                logs.logEvent("rootStore::setActiveCommunity", ["communityId"], arguments)
            }
        }
        fnIsMyCommunityRequestPending: function isMyCommunityRequestPending(communityId) {
            return communityId === "0x0006"
        }

        currencyStore: currencyStore
        walletAssetsStore: walletAssetsStore

        onLeaveCommunityRequest: logs.logEvent("onLeaveCommunityRequest", ["communityId"], arguments)
        onSetCommunityMutedRequest: logs.logEvent("onSetCommunityMutedRequest", ["communityId", "mutedType"], arguments)
        onCancelPendingRequestRequested: logs.logEvent("onCancelPendingRequestRequested", ["communityId"], arguments)
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 200

        logsView.logText: logs.logText

        Switch {
            id: ctrlEmptyView
            text: "No communities"
        }
    }
}

// category: Views
// status: good
// https://www.figma.com/file/idUoxN7OIW2Jpp3PMJ1Rl8/%E2%9A%99%EF%B8%8F-Settings-%7C-Desktop?type=design&node-id=16089-387522&t=HRT9BmZXnl7Lt55Q-0
