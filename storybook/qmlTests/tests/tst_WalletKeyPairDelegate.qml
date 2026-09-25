import QtQuick
import QtTest

import AppLayouts.Profile.controls

import utils

Item {
    id: root
    width: 560
    height: 400

    readonly property string lowercaseAddress: "0xcdc2ea3b6ba8fed3a3402f8db8b2fab53e7b7421"
    readonly property string checksumAddress: "0xcDC2Ea3b6bA8FEd3a3402F8dB8b2fAb53E7B7421"

    ListModel {
        id: accountsModel
    }

    Component {
        id: componentUnderTest

        WalletKeyPairDelegate {
            width: root.width
            userProfilePublicKey: ""
            hasPairedDevices: false
        }
    }

    TestCase {
        name: "WalletKeyPairDelegate"
        when: windowShown

        property WalletKeyPairDelegate controlUnderTest: null

        function cleanup() {
            if (!!controlUnderTest) {
                controlUnderTest.destroy()
                controlUnderTest = null
            }
            accountsModel.clear()
        }

        function createWatchOnlyDelegate(hideFromTotalBalance) {
            cleanup()
            accountsModel.append({
                account: {
                    name: "Watched",
                    emoji: "",
                    colorId: "primary",
                    address: root.lowercaseAddress,
                    mixedcaseAddress: root.checksumAddress,
                    hideFromTotalBalance: hideFromTotalBalance
                }
            })
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                keyPair: {
                    pairType: Constants.keypair.type.watchOnly,
                    migratedToColdWallet: false,
                    operability: Constants.keypair.operability.fullyOperable,
                    name: "Watched",
                    pubKey: "",
                    icon: "",
                    image: "",
                    accounts: accountsModel
                }
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)
            return controlUnderTest
        }

        function test_watchOnlyTitleAndMoreButtonHidden() {
            createWatchOnlyDelegate(true)

            const header = findChild(controlUnderTest, "walletKeyPairDelegate")
            verify(!!header)
            compare(header.title, qsTr("Watched addresses"))

            const moreButton = findChild(controlUnderTest, "walletKeyPairDelegateMoreButton-Watched")
            verify(!!moreButton)
            verify(!moreButton.visible)
        }

        function test_watchOnlyInclusionBadge() {
            createWatchOnlyDelegate(true)
            compare(findChild(controlUnderTest, "watchAccountInclusionLabel").text, qsTr("Excluded"))

            createWatchOnlyDelegate(false)
            compare(findChild(controlUnderTest, "watchAccountInclusionLabel").text, qsTr("Included"))
        }
    }
}
