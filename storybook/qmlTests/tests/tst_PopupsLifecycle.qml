import QtQuick
import QtTest

import StatusQ

import AppLayouts.stores as AppLayoutStores
import AppLayouts.Communities.stores
import mainui
import shared.stores
import utils

// Lifetime of popups that Popups builds on demand.
Item {
    id: root

    width: 800
    height: 800

    Component {
        id: popupsWithFetchComponent

        Popups {
            popupParent: root
            keychain: Keychain {}
            secureStorage: SecureStorage {}
            sharedRootStore: RootStore {}
            rootStore: AppLayoutStores.RootStore {}
            communityTokensStore: CommunityTokensStore {}
            networksStore: NetworksStore {}
            communitiesStore: CommunitiesStore {
                property int communityFetchState: Constants.CommunityFetchState.Fetching
                property int communityFetchTimeoutSeconds: 30
            }
        }
    }

    Component {
        id: popupsComponent

        Popups {
            popupParent: root
            keychain: Keychain {}
            secureStorage: SecureStorage {}
            sharedRootStore: RootStore {}
            rootStore: AppLayoutStores.RootStore {}
            communityTokensStore: CommunityTokensStore {}
            networksStore: NetworksStore {}
            activityCenterStore: AppLayoutStores.ActivityCenterStore {}
        }
    }

    Component {
        id: notificationComponent

        QtObject {
            property string id: "1"
            property string newsTitle: "Title"
            property string newsContent: "Content"
            property string newsLink: ""
            property string newsLinkLabel: ""
            property string newsImageUrl: ""
            property double timestamp: Date.now()
        }
    }

    TestCase {
        name: "PopupsLifecycle"
        when: windowShown

        function init() {
            // Popups builds its signing/auth/keycard stores up front; they reach for
            // backend context the test does not provide.
            ignoreWarning(/AuthenticationStore\.qml:\d+: ReferenceError: mainModule is not defined/)
            ignoreWarning(/SigningStore\.qml:\d+: ReferenceError: mainModule is not defined/)
            ignoreWarning(/KeycardManagementStore\.qml:\d+: ReferenceError: mainModule is not defined/)
        }

        property var watched: null  // a var drops to null when its object is destroyed

        function test_newsMessagePopupIsDestroyedOnClose() {
            const popups = createTemporaryObject(popupsComponent, root)
            const notification = createTemporaryObject(notificationComponent, root)

            // pre-existing: Popups passes a notificationId the popup does not declare
            ignoreWarning(/NewsMessagePopupInstance does not have a property called notificationId/)
            popups.openNewsMessagePopup(notification, notification.id)
            watched = popups.currentPopup
            verify(!!watched)
            tryCompare(watched, "opened", true)

            watched.close()
            tryVerify(() => watched === null)
        }

        function test_communityFetchInProgressBeforeLoadShowsTheDialog() {
            const popups = createTemporaryObject(popupsWithFetchComponent, root)

            tryVerify(() => popups.communityFetchPopupComponent.instance?.opened ?? false)
            popups.communityFetchPopupComponent.instance.close()
        }
    }
}
