import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQml.Models
import QtQml
import StatusQ
import StatusQ.Core
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups
import StatusQ.Popups.Dialog
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import AppLayouts.stores as AppLayoutStores
import AppLayouts.Chat.popups
import AppLayouts.Profile.popups
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Communities.popups
import AppLayouts.Communities.helpers
import AppLayouts.Wallet.popups.buy
import AppLayouts.Wallet.popups
import AppLayouts.Wallet.helpers
import AppLayouts.Communities.stores
import AppLayouts.Profile.helpers
import AppLayouts.Wallet.services.dapps
import mainui.popups
import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.Chat.stores as ChatStores
import AppLayouts.stores.Messaging as MessagingStores
import AppLayouts.stores.Messaging.Community as CommunityStores
import shared.popups
import shared.popups.authentication
import shared.popups.authentication.stores 1.0 as AuthStores
import shared.popups.signing
import shared.popups.signing.stores 1.0 as SignStores
import shared.popups.keycard_new
import shared.popups.keycard_new.stores 1.0 as KeycardMgmtStores
import shared.status
import shared.stores
import shared.views
import shared.views.profile
import utils

FinaliseOwnershipPopup {
    id: finalisePopup

    required property Popups host

    property string communityId
    readonly property var ownerTokenDetails: finalisePopup.host.communityTokensStore.ownerTokenDetails
    readonly property var communityData : finalisePopup.host.communitiesStore.getCommunityDetailsAsJson(communityId)

    readonly property TransactionFeesBroker feesBroker: TransactionFeesBroker {
        communityTokensStore: finalisePopup.host.communityTokensStore
        active: finalisePopup.contentItem.Window.window.active
    }

    Component.onCompleted: finalisePopup.host.communityTokensStore.asyncGetOwnerTokenDetails(communityId)

    communityName: communityData.name
    communityLogo: communityData.image
    communityColor: communityData.color

    tokenSymbol: ownerTokenDetails.symbol
    tokenChainName: ownerTokenDetails.chainName

    feeText: feeSubscriber.feeText
    feeErrorText: feeSubscriber.feeErrorText
    isFeeLoading: !feeSubscriber.feesResponse

    accounts: WalletStores.RootStore.nonWatchAccounts

    destroyOnClose: true

    onRejectClicked: Global.openDeclineOwnershipPopup(finalisePopup.communityId, communityData.name)
    onFinaliseOwnershipClicked: signPopup.open()

    onVisitCommunityClicked: finalisePopup.host.communitiesStore.navigateToCommunity(finalisePopup.communityId)
    onOpenControlNodeDocClicked:(link) => Global.requestOpenLink(link)

    onCalculateFees: {
        feesBroker.registerSetSignerFeesSubscriber(feeSubscriber)
    }

    onStopUpdatingFees: {
        finalisePopup.host.communityTokensStore.stopUpdatesForSuggestedRoute()
    }

    onClosed: {
        finalisePopup.host.communityTokensStore.stopUpdatesForSuggestedRoute()
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

        title: qsTr("Sign transaction - update %1 smart contract").arg(finalisePopup.communityName)
        totalFeeText: finalisePopup.isFeeLoading ? "" : finalisePopup.feeText
        errorText: finalisePopup.feeErrorText
        accountName: finalisePopup.ownerTokenDetails.accountName
        migratedToColdWallet: !!SQUtils.ModelUtils.getByKey(finalisePopup.host.rootStore.walletAccountsModel,
                                                            "address",
                                                            finalisePopup.selectedAccountAddress,
                                                            "migratedToColdWallet")
        keyUid: SQUtils.ModelUtils.getByKey(finalisePopup.host.rootStore.walletAccountsModel,
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
            finalisePopup.host.communityTokensStore.authenticateAndTransfer()
        }
    }

    Connections {
        target: finalisePopup.host
        function onOwnershipDeclined(communityId: string, communityName: string) {
            finalisePopup.close()
            finalisePopup.host.communityTokensStore.ownershipDeclined(communityId, communityName)
        }
    }
}
