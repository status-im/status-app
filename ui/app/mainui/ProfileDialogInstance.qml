import AppLayouts.stores as AppLayoutStores
import AppLayouts.Wallet.stores as WalletStores

import shared.popups
import shared.stores

import utils

ProfileDialog {
    id: profilePopup

    required property NetworkConnectionStore networkConnectionStore
    required property AppLayoutStores.RootStore rootStore

    property string publicKey
    readonly property bool isCurrentUser: contactDetails.isCurrentUser

    walletStore: WalletStores.RootStore

    sendToAccountEnabled: profilePopup.networkConnectionStore.walletReadyForTransactionsEnabled

    showcaseCommunitiesModel: isCurrentUser ? profilePopup.profileStore.ownShowcaseCommunitiesModel
                                            : profilePopup.contactsStore.contactShowcaseCommunitiesModel
    showcaseAccountsModel: isCurrentUser ? profilePopup.profileStore.ownShowcaseAccountsModel
                                         : profilePopup.contactsStore.contactShowcaseAccountsModel
    showcaseCollectiblesModel: isCurrentUser ? profilePopup.profileStore.ownShowcaseCollectiblesModel
                                             : profilePopup.contactsStore.contactShowcaseCollectiblesModel
    showcaseSocialLinksModel: isCurrentUser ? profilePopup.profileStore.ownShowcaseSocialLinksModel
                                            : profilePopup.contactsStore.contactShowcaseSocialLinksModel

    assetsModel: profilePopup.rootStore.globalAssetsModel
    collectiblesModel: profilePopup.rootStore.globalCollectiblesModel

    onOpened: {
        isCurrentUser ? profilePopup.profileStore.requestProfileShowcasePreferences()
                      : profilePopup.contactsStore.requestContactShowcase(publicKey)
    }
    onClosed: {
        if (profilePopup.parentPopup) {
            profilePopup.parentPopup.close()
        }
    }

    onNavigationRequested: Global.closeActivityCenterRequested()
}
