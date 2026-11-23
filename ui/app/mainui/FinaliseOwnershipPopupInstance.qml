import QtQuick

import StatusQ.Core.Utils as SQUtils

import AppLayouts.stores as AppLayoutStores
import AppLayouts.Communities.helpers
import AppLayouts.Communities.popups
import AppLayouts.Communities.stores as CommunitiesStores
import AppLayouts.Wallet.stores as WalletStores

import shared.stores

import utils

FinaliseOwnershipPopup {
    id: finalisePopup

    required property CommunityTokensStore communityTokensStore
    required property CommunitiesStores.CommunitiesStore communitiesStore
    required property AppLayoutStores.RootStore rootStore

    property string communityId
    readonly property var ownerTokenDetails: finalisePopup.communityTokensStore.ownerTokenDetails
    readonly property var communityData : finalisePopup.communitiesStore.getCommunityDetailsAsJson(communityId)

    readonly property TransactionFeesBroker feesBroker: TransactionFeesBroker {
        communityTokensStore: finalisePopup.communityTokensStore
        active: finalisePopup.contentItem.Window.window.active
    }

    Component.onCompleted: finalisePopup.communityTokensStore.asyncGetOwnerTokenDetails(communityId)

    communityName: communityData.name
    communityLogo: communityData.image
    communityColor: communityData.color

    tokenSymbol: ownerTokenDetails.symbol
    tokenChainName: ownerTokenDetails.chainName

    feeText: feeSubscriber.feeText
    feeErrorText: feeSubscriber.feeErrorText
    isFeeLoading: !feeSubscriber.feesResponse

    accounts: WalletStores.RootStore.nonWatchAccounts

    onRejectClicked: Global.openDeclineOwnershipPopup(finalisePopup.communityId, communityData.name)
    onFinaliseOwnershipClicked: signPopup.open()

    onVisitCommunityClicked: finalisePopup.communitiesStore.navigateToCommunity(finalisePopup.communityId)
    onOpenControlNodeDocClicked:(link) => Global.requestOpenLink(link)

    onCalculateFees: {
        feesBroker.registerSetSignerFeesSubscriber(feeSubscriber)
    }

    onStopUpdatingFees: {
        finalisePopup.communityTokensStore.stopUpdatesForSuggestedRoute()
    }

    onClosed: {
        finalisePopup.communityTokensStore.stopUpdatesForSuggestedRoute()
    }

    SetSignerFeesSubscriber {
        id: feeSubscriber
        communityId: finalisePopup.communityId
        chainId: finalisePopup.ownerTokenDetails.chainId
        contractAddress: finalisePopup.ownerTokenDetails.contractAddress
        accountAddress: finalisePopup.selectedAccountAddress
        enabled: finalisePopup.visible || signPopup.visible
    }

    SignTransactionsPopup {
        id: signPopup

        title: qsTranslate("Popups", "Sign transaction - update %1 smart contract").arg(finalisePopup.communityName)
        totalFeeText: finalisePopup.isFeeLoading ? "" : finalisePopup.feeText
        errorText: finalisePopup.feeErrorText
        accountName: finalisePopup.ownerTokenDetails.accountName
        migratedToColdWallet: !!SQUtils.ModelUtils.getByKey(finalisePopup.rootStore.walletAccountsModel,
                                                            "address",
                                                            finalisePopup.selectedAccountAddress,
                                                            "migratedToColdWallet")
        keyUid: SQUtils.ModelUtils.getByKey(finalisePopup.rootStore.walletAccountsModel,
                                            "address",
                                            finalisePopup.selectedAccountAddress,
                                            "keyUid") ?? ""

        model: QtObject {
            readonly property string title: finalisePopup.feeLabel
            readonly property string feeText: signPopup.totalFeeText
            readonly property bool error: finalisePopup.feeErrorText !== ""
        }

        onSignTransactionClicked: {
            finalisePopup.close()
            finalisePopup.communityTokensStore.authenticateAndTransfer()
        }
    }
}
