import QtQuick
import QtTest

import StatusQ

import AppLayouts.stores as AppLayoutStores
import AppLayouts.Profile.stores as ProfileStores
import mainui
import shared.stores
import utils

// Moving the profile key pair to a keycard removes the boot-login record together with
// the "Stay logged in" credential.
Item {
    id: root

    width: 800
    height: 800

    Component {
        id: popupsComponent

        Popups {
            popupParent: root
            keychain: Keychain {}
            secureStorage: SecureStorage {
                property int deleteStatus: SecureStorage.StatusSuccess
                property string bootLoginRecord: "{\"version\":1}"

                function deleteCredential(account) {
                    return deleteStatus
                }
                function deleteBootLoginRecord() {
                    if (bootLoginRecord === "")
                        return SecureStorage.StatusNotFound
                    bootLoginRecord = ""
                    return SecureStorage.StatusSuccess
                }
            }
            privacyStore: ProfileStores.PrivacyStore {
                property QtObject privacyModule: QtObject {
                    signal passwordChanged(bool success, string errorMsg)
                }
                function setStayLoggedIn(value) {}
            }
            sharedRootStore: RootStore {}
            rootStore: AppLayoutStores.RootStore {}
            communityTokensStore: CommunityTokensStore {}
            networksStore: NetworksStore {}
        }
    }

    TestCase {
        name: "PopupsKeycardMoveBootLoginRecord"
        when: windowShown

        property Popups popups

        function init() {
            // Popups builds its signing/auth/keycard stores up front; they reach for
            // backend context the test does not provide.
            ignoreWarning(/Popups\.qml:\d+: TypeError: Cannot read property 'communityFetch.*' of null/)
            ignoreWarning(/Popups\.qml:\d+: TypeError: Cannot read property 'communityFetch.*' of null/)
            ignoreWarning(/AuthenticationStore\.qml:\d+: ReferenceError: mainModule is not defined/)
            ignoreWarning(/SigningStore\.qml:\d+: ReferenceError: mainModule is not defined/)
            ignoreWarning(/KeycardManagementStore\.qml:\d+: ReferenceError: mainModule is not defined/)
            popups = createTemporaryObject(popupsComponent, root)
            verify(!!popups)
        }

        function test_startingTheMoveRemovesTheRecord() {
            // An unverified credential delete refuses the move before any popup opens
            popups.secureStorage.deleteStatus = SecureStorage.StatusGenericError

            popups.openKeycardManagementPopup(Constants.keycard.flow.moveProfileKeyPair,
                                              "", "", "", "", false)

            compare(popups.secureStorage.bootLoginRecord, "")
        }

        function test_finishedMoveRemovesTheRecord() {
            popups.keycardManagementStore.keycardMoveProfileKeyPairSuccess()

            compare(popups.secureStorage.bootLoginRecord, "")
        }
    }
}
