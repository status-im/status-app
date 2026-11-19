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

ProfileDialog {
    id: profilePopup

    required property Popups host

    property string publicKey
    readonly property bool isCurrentUser: contactDetails.isCurrentUser

    profileStore: profilePopup.host.profileStore
    contactsStore: profilePopup.host.contactsStore
    walletStore: WalletStores.RootStore
    utilsStore: profilePopup.host.utilsStore
    networksStore: profilePopup.host.networksStore

    sendToAccountEnabled: profilePopup.host.networkConnectionStore.walletReadyForTransactionsEnabled

    showcaseCommunitiesModel: isCurrentUser ? profilePopup.host.profileStore.ownShowcaseCommunitiesModel
                                            : profilePopup.host.contactsStore.contactShowcaseCommunitiesModel
    showcaseAccountsModel: isCurrentUser ? profilePopup.host.profileStore.ownShowcaseAccountsModel
                                         : profilePopup.host.contactsStore.contactShowcaseAccountsModel
    showcaseCollectiblesModel: isCurrentUser ? profilePopup.host.profileStore.ownShowcaseCollectiblesModel
                                             : profilePopup.host.contactsStore.contactShowcaseCollectiblesModel
    showcaseSocialLinksModel: isCurrentUser ? profilePopup.host.profileStore.ownShowcaseSocialLinksModel
                                            : profilePopup.host.contactsStore.contactShowcaseSocialLinksModel

    assetsModel: profilePopup.host.rootStore.globalAssetsModel
    collectiblesModel: profilePopup.host.rootStore.globalCollectiblesModel

    onOpened: {
        isCurrentUser ? profilePopup.host.profileStore.requestProfileShowcasePreferences()
                      : profilePopup.host.contactsStore.requestContactShowcase(publicKey)
    }
    onClosed: {
        if (profilePopup.parentPopup) {
            profilePopup.parentPopup.close()
        }
        destroy()
    }

    onNavigationRequested: Global.closeActivityCenterRequested()
}
