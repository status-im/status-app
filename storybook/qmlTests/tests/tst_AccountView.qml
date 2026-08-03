import QtQuick
import QtTest

import AppLayouts.Profile.views.wallet
import AppLayouts.Profile.stores as ProfileStores

import utils

Item {
    id: root

    width: 600
    height: 800

    readonly property string lowercaseAddress: "0xcdc2ea3b6ba8fed3a3402f8db8b2fab53e7b7421"
    readonly property string checksumAddress: "0xcDC2Ea3b6bA8FEd3a3402F8dB8b2fAb53E7B7421"

    QtObject {
        id: globalUtilsMock
        function isCompressedPubKey(_publicKey) { return false }
        function getCompressedPk(publicKey) { return publicKey }
    }

    ProfileStores.WalletStore {
        id: walletStoreMock
    }

    ListModel {
        id: emptyNetworks
    }

    Component {
        id: componentUnderTest

        AccountView {
            width: root.width
            walletStore: walletStoreMock
            activeNetworks: emptyNetworks
            emojiPopup: null
            userProfilePublicKey: ""
            keyPair: ({
                          pairType: Constants.keypair.type.profile,
                          migratedToColdWallet: false,
                          operability: Constants.keypair.operability.fullyOperable,
                          name: "Profile",
                          pubKey: "",
                          icon: "",
                          image: "",
                          accounts: []
                      })
        }
    }

    TestCase {
        name: "AccountView"
        when: windowShown

        property var controlUnderTest: null

        function initTestCase() {
            Utils.globalUtilsInst = globalUtilsMock
        }

        function cleanupTestCase() {
            Utils.globalUtilsInst = null
        }

        function cleanup() {
            if (!!controlUnderTest) {
                controlUnderTest.destroy()
                controlUnderTest = null
            }
        }

        function createView(account) {
            cleanup()
            controlUnderTest = createTemporaryObject(componentUnderTest, root, { account: account })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)
            return controlUnderTest
        }

        function test_addressListItemShowsMixedcaseAddress() {
            createView({
                            name: "Status account",
                            address: root.lowercaseAddress,
                            mixedcaseAddress: root.checksumAddress,
                            emoji: "",
                            colorId: "primary",
                            path: "m/44'/60'/0'/0/0",
                            isDefaultAccount: true,
                            hideFromTotalBalance: false,
                            balance: null
                        })

            const addressItem = findChild(controlUnderTest, "Address_ListItem")
            verify(!!addressItem)
            compare(addressItem.subTitle, root.checksumAddress)
        }

        function test_addressListItemFallsBackToAddress() {
            createView({
                            name: "Status account",
                            address: root.lowercaseAddress,
                            mixedcaseAddress: "",
                            emoji: "",
                            colorId: "primary",
                            path: "m/44'/60'/0'/0/0",
                            isDefaultAccount: true,
                            hideFromTotalBalance: false,
                            balance: null
                        })

            const addressItem = findChild(controlUnderTest, "Address_ListItem")
            verify(!!addressItem)
            compare(addressItem.subTitle, root.lowercaseAddress)
        }
    }
}
