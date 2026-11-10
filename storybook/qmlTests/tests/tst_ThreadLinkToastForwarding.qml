import QtQuick
import QtTest
import StatusQ.Core.Theme
import "../../../ui/app/AppLayouts/stores" as AppStores
Item {
    QtObject {
        id: backend
        property bool isOnline: true
        property bool isMessagingNetworkConnected: true
        property bool sectionsLoaded: true
        property var sectionsModel: null
        property var ephemeralNotificationModel: null
        property QtObject activeSection: QtObject {
            property string id: "chats"
            property int sectionType: 0
        }
        property QtObject appSearchModule: QtObject {
            property var locationMenuModel: null
            property var threadLocationMenuModel: null
            property var resultModel: null
            property var chatSearchModel: null
            property bool threadLocationsLoading: false
            property bool threadLocationsError: false
            signal appSearchCompleted()
        }
        signal showToastThreadLinkFailed()
    }
    Component {
        id: storeComponent
        AppStores.RootStore {
            property var mainModule: backend
            property bool production: false
            property var appSettings: null
            keychain: null
            palette: Theme.palette
            _walletRelatedMainModuleConnections.target: backend
            _walletRelatedMainModuleConnections.ignoreUnknownSignals: true
            _mainModuleConnections.ignoreUnknownSignals: true
            _notificationsRelatedMainModuleConnections.ignoreUnknownSignals: true
            _communityRelatedMainModuleConnections.ignoreUnknownSignals: true
            keycardRelatedMainModuleConnections.ignoreUnknownSignals: true
            communitiesModuleInst: QtObject {
                property string myRevealedAddressesStringForCurrentCommunity: "[]"
                property string myRevealedAirdropAddressForCurrentCommunity: ""
                property bool checkingPermissionToJoinInProgress: false
                property bool joinPermissionsCheckCompletedWithoutErrors: false
                property bool channelsPermissionsCheckSuccessful: false
                property var tokenList: null
                property var collectiblesModel: null
            }
        }
    }
    SignalSpy { id: spy; signalName: "showToastThreadLinkFailed" }
    TestCase {
        name: "ThreadLinkToastForwarding"
        when: windowShown
        function test_failureForwarded() {
            const store = createTemporaryObject(storeComponent, parent)
            verify(store)
            spy.target = store
            verify(spy.valid)
            backend.showToastThreadLinkFailed()
            compare(spy.count, 1)
        }
    }
}
