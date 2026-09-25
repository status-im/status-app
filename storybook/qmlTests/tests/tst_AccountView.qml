import QtQuick
import QtTest

import AppLayouts.Profile.views.wallet
import AppLayouts.Profile.stores as ProfileStores

import StatusQ.Core

import utils

Item {
    id: root

    width: 600
    height: 800

    readonly property string lowercaseAddress: "0xcdc2ea3b6ba8fed3a3402f8db8b2fab53e7b7421"
    readonly property string checksumAddress: "0xcDC2Ea3b6bA8FEd3a3402F8dB8b2fAb53E7B7421"

    function usdAmount(amount) {
        return {
            amount: amount,
            symbol: "USD",
            displayDecimals: 2,
            stripTrailingZeroes: false
        }
    }

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

    SignalSpy {
        id: toggleSpy
        signalName: "updateWatchAccountHiddenFromTotalBalance"
    }

    TestCase {
        name: "AccountView"
        when: windowShown

        property AccountView controlUnderTest: null

        function initTestCase() {
            Utils.globalUtilsInst = globalUtilsMock
        }

        function cleanupTestCase() {
            Utils.globalUtilsInst = null
        }

        function cleanup() {
            toggleSpy.target = null
            toggleSpy.clear()
            if (!!controlUnderTest) {
                controlUnderTest.destroy()
                controlUnderTest = null
            }
        }

        function profileAccount(extra) {
            extra = extra || {}
            return {
                name: extra.name || "Status account",
                address: extra.address || root.lowercaseAddress,
                mixedcaseAddress: extra.mixedcaseAddress !== undefined ? extra.mixedcaseAddress : root.checksumAddress,
                emoji: extra.emoji || "",
                colorId: extra.colorId || "primary",
                path: extra.path !== undefined ? extra.path : "m/44'/60'/0'/0/0",
                isDefaultAccount: extra.isDefaultAccount !== undefined ? extra.isDefaultAccount : true,
                hideFromTotalBalance: extra.hideFromTotalBalance || false,
                balance: extra.balance !== undefined ? extra.balance : null
            }
        }

        function watchOnlyKeyPair() {
            return {
                pairType: Constants.keypair.type.watchOnly,
                migratedToColdWallet: false,
                operability: Constants.keypair.operability.fullyOperable,
                name: "",
                pubKey: "",
                icon: "",
                image: "",
                accounts: []
            }
        }

        function child(objectName) {
            return findChild(controlUnderTest, objectName)
        }

        function createView(account, keyPair) {
            cleanup()
            const props = { account: account }
            if (keyPair)
                props.keyPair = keyPair
            controlUnderTest = createTemporaryObject(componentUnderTest, root, props)
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)
            toggleSpy.target = controlUnderTest
            return controlUnderTest
        }

        function test_addressListItemShowsMixedcaseAddress() {
            createView(profileAccount())
            compare(child("Address_ListItem").subTitle, root.checksumAddress)
        }

        function test_addressListItemFallsBackToAddress() {
            createView(profileAccount({ mixedcaseAddress: "" }))
            compare(child("Address_ListItem").subTitle, root.lowercaseAddress)
        }

        function test_profileAccountHidesIncludeInTotalBalanceAndShowsDerivationPath() {
            createView(profileAccount())
            verify(!child("includeTotalBalanceListItem").visible)
            verify(child("DerivationPath_ListItem").visible)
        }

        function test_watchOnlyAccountDetailsAndIncludeToggle() {
            const balance = root.usdAmount(12.5)
            createView(profileAccount({
                name: "Watched",
                path: "",
                isDefaultAccount: false,
                hideFromTotalBalance: true,
                balance: balance
            }), watchOnlyKeyPair())

            compare(child("walletAccountViewAccountName").text, "Watched")
            compare(child("Address_ListItem").subTitle, root.checksumAddress)
            compare(child("Origin_ListItem").subTitle, qsTr("Watched address"))
            compare(child("Balance_ListItem").subTitle, LocaleUtils.currencyAmountToLocaleString(balance))
            verify(!child("DerivationPath_ListItem").visible)
            verify(!child("Stored_ListItem").visible)
            verify(child("includeTotalBalanceListItem").visible)

            const includeSwitch = child("includeTotalBalanceSwitch")
            verify(!includeSwitch.checked)
            mouseClick(includeSwitch)
            compare(toggleSpy.count, 1)
            compare(toggleSpy.signalArguments[0][0], root.lowercaseAddress)
            compare(toggleSpy.signalArguments[0][1], false)
        }
    }
}
