import QtQuick
import QtQuick.Controls
import QtTest
import QtQml

import Models

import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Theme

import AppLayouts.Wallet.popups.swap

import utils

Item {
    id: root
    width: 600
    height: 400

    Component {
        id: componentUnderTest
        SwapSignModal {
            anchors.centerIn: parent

            formatBigNumber: (number, symbol, noSymbolOption) => parseFloat(number).toLocaleString(Qt.locale(), 'f', 2) + (noSymbolOption ? "" : " " + symbol)

            fromTokenSymbol: "DAI"
            fromTokenAmount: "100.07"
            fromTokenContractAddress: "0x6B175474E89094C44Da98b954EedeAC495271d0F"

            toTokenSymbol: "USDT"
            toTokenAmount: "142.07"
            toTokenContractAddress: "0xdAC17F958D2ee523a2206206994597C13D831ec7"

            accountName: "Hot wallet (generated)"
            accountAddress: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881"
            accountEmoji: "🚗"
            accountColor: Utils.getColorForId(Theme.palette, Constants.walletAccountColors.primary)

            toAccountName: "Cold wallet"
            toAccountAddress: "0x1A47C2e98a4BBf5487E6fb082eC2D9Ab0E6d1234"
            toAccountEmoji: "🧊"
            toAccountColor: Utils.getColorForId(Theme.palette, Constants.walletAccountColors.army)

            toNetworkName: "Optimism"
            toNetworkShortName: Constants.networkShortChainNames.optimism
            toNetworkIconPath: Assets.svg("network/optimism")
            toNetworkBlockExplorerUrl: "https://optimistic.etherscan.io/"
            toNetworkChainId: 10

            networkShortName: Constants.networkShortChainNames.mainnet
            networkName: "Mainnet"
            networkIconPath: Assets.svg("network/ethereum")
            networkBlockExplorerUrl: "https://etherscan.io/"
            networkChainId: 1

            serviceProviderName: Constants.swap.paraswapName
            serviceProviderURL: Constants.swap.paraswapUrl
            txProviderTool: "sushiswap"

            fiatFees: "1.54 EUR"
            cryptoFees: "0.001 ETH"
            slippage: 0.2

            keyUid: ""
            migratedToColdWallet: false
        }
    }

    SignalSpy {
        id: signalSpyAccepted
        target: controlUnderTest
        signalName: "accepted"
    }

    SignalSpy {
        id: signalSpyRejected
        target: controlUnderTest
        signalName: "rejected"
    }

    property SwapSignModal controlUnderTest: null

    TestCase {
        name: "SwapSignModal"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)

            // Open the dialog and wait until it is fully initialized so geometry bindings resolve correctly
            verify(!!controlUnderTest)
            controlUnderTest.open()
            tryVerify(() => controlUnderTest.opened === true, 1000)

            signalSpyAccepted.clear()
            signalSpyRejected.clear()

            // Reset the shared userProfile mock so icon tests start from a known state
            userProfile.usingBiometricLogin = false
        }

        function test_basicGeometry() {
            verify(!!controlUnderTest)
            verify(controlUnderTest.width > 0)
            verify(controlUnderTest.height > 0)
        }

        function test_fromToProps_data() {
            return [
                        {tag: "ETH", toTokenSymbol: "ETH"},
                        {tag: "DAI", toTokenSymbol: "DAI"},
                    ]
        }

        function test_fromToProps(data) {
            verify(!!controlUnderTest)
            controlUnderTest.fromTokenSymbol = "SNT"
            controlUnderTest.fromTokenAmount = "1000.123456789"
            controlUnderTest.fromTokenContractAddress = "Oxdeadbeef"
            controlUnderTest.toTokenSymbol = data.toTokenSymbol
            controlUnderTest.toTokenAmount = "1.42"
            controlUnderTest.toTokenContractAddress = "0xdeadcaff"

            // subtitle
            compare(controlUnderTest.subtitle, qsTr("%1 to %2").arg(controlUnderTest.formatBigNumber(controlUnderTest.fromTokenAmount, controlUnderTest.fromTokenSymbol))
                    .arg(controlUnderTest.formatBigNumber(controlUnderTest.toTokenAmount, controlUnderTest.toTokenSymbol)))

            // info box
            const headerText = findChild(controlUnderTest.contentItem, "headerText")
            verify(!!headerText)
            compare(headerText.text, qsTr("From %1 1,000.12 SNT on %2 to %3 1.42 %4 on %5")
                    .arg(controlUnderTest.accountName).arg(controlUnderTest.networkName)
                    .arg(controlUnderTest.toAccountName).arg(data.toTokenSymbol)
                    .arg(controlUnderTest.toNetworkName))
            const fromImage = findChild(controlUnderTest.contentItem, "fromImageIdenticon")
            verify(!!fromImage)
            compare(fromImage.asset.name, Constants.tokenIcon(controlUnderTest.fromTokenSymbol))
            const toImage = findChild(controlUnderTest.contentItem, "toImageIdenticon")
            verify(!!toImage)
            compare(toImage.asset.name, Constants.tokenIcon(controlUnderTest.toTokenSymbol))

            // pay box
            const payBox = findChild(controlUnderTest.contentItem, "payBox")
            verify(!!payBox)
            compare(payBox.caption, qsTr("Pay"))
            compare(payBox.primaryText, "1,000.12 SNT")
            compare(payBox.secondaryText, SQUtils.Utils.elideAndFormatWalletAddress(controlUnderTest.fromTokenContractAddress))

            // receive box
            const receiveBox = findChild(controlUnderTest.contentItem, "receiveBox")
            verify(!!receiveBox)
            compare(receiveBox.caption, qsTr("Receive"))
            compare(receiveBox.primaryText, "%1 %2".arg(controlUnderTest.toTokenAmount).arg(controlUnderTest.toTokenSymbol))
            compare(receiveBox.secondaryText,
                    data.toTokenSymbol === "ETH" ? ""
                                                 : SQUtils.Utils.elideAndFormatWalletAddress(controlUnderTest.toTokenContractAddress))

            // each side badges its own network — they differ when bridging
            compare(payBox.badge, controlUnderTest.networkIconPath)
            compare(receiveBox.badge, controlUnderTest.toNetworkIconPath)
        }

        function test_accountInfo() {
            verify(!!controlUnderTest)

            // account box
            const accountBox = findChild(controlUnderTest.contentItem, "accountBox")
            verify(!!accountBox)

            compare(accountBox.caption, qsTr("From account"))
            compare(accountBox.primaryText, controlUnderTest.accountName)
            compare(accountBox.secondaryText, SQUtils.Utils.elideAndFormatWalletAddress(controlUnderTest.accountAddress))
            compare(accountBox.asset.emoji, controlUnderTest.accountEmoji)
            compare(accountBox.asset.color, controlUnderTest.accountColor)

            // to-account box
            const toAccountBox = findChild(controlUnderTest.contentItem, "toAccountBox")
            verify(!!toAccountBox)

            compare(toAccountBox.caption, qsTr("To account"))
            compare(toAccountBox.primaryText, controlUnderTest.toAccountName)
            compare(toAccountBox.secondaryText, SQUtils.Utils.elideAndFormatWalletAddress(controlUnderTest.toAccountAddress))
            compare(toAccountBox.asset.emoji, controlUnderTest.toAccountEmoji)
            compare(toAccountBox.asset.color, controlUnderTest.toAccountColor)
        }

        function test_removedRepeatedBoxes() {
            verify(!!controlUnderTest)

            // network and fees info moved to the footer/route views — no boxes here
            verify(!findChild(controlUnderTest.contentItem, "networkBox"))
            verify(!findChild(controlUnderTest.contentItem, "feesBox"))
        }

        function test_loginType_data() {
            return [
                { tag: "password", biometric: false, migrated: false, iconName: "password" },
                { tag: "touchId", biometric: true, migrated: false, iconName: "touch-id" },
                { tag: "keycard", biometric: false, migrated: true, iconName: "keycard" }
            ]
        }

        function test_loginType(data) {
            verify(!!controlUnderTest)

            userProfile.usingBiometricLogin = data.biometric
            controlUnderTest.migratedToColdWallet = data.migrated

            const signButton = findChild(controlUnderTest.footer, "signButton")
            verify(!!signButton)
            compare(signButton.icon.name, data.iconName)
        }

        function test_loading() {
            verify(!!controlUnderTest)

            compare(controlUnderTest.feesLoading, false)

            const signButton = findChild(controlUnderTest.footer, "signButton")
            verify(!!signButton)
            compare(signButton.interactive, true)

            const footerFiatFeesText = findChild(controlUnderTest.footer, "footerFiatFeesText")
            verify(!!footerFiatFeesText)
            compare(footerFiatFeesText.loading, false)

            controlUnderTest.feesLoading = true

            compare(signButton.interactive, false)
            compare(footerFiatFeesText.loading, true)
        }

        function test_footerInfo() {
            verify(!!controlUnderTest)

            const fiatFeesText = findChild(controlUnderTest.footer, "footerFiatFeesText")
            verify(!!fiatFeesText)
            compare(fiatFeesText.text, controlUnderTest.fiatFees)

            const maxSlippageText = findChild(controlUnderTest.footer, "footerMaxSlippageText")
            verify(!!maxSlippageText)
            compare(maxSlippageText.text, "%1%".arg(controlUnderTest.slippage))
        }

        function test_signButton() {
            verify(!!controlUnderTest)

            const signButton = findChild(controlUnderTest.footer, "signButton")
            verify(!!signButton)
            compare(signButton.interactive, true)

            signButton.clicked()
            compare(signalSpyAccepted.count, 1)
            compare(controlUnderTest.opened, false)
            compare(controlUnderTest.result, Dialog.Accepted)
        }

        function test_rejectButton() {
            verify(!!controlUnderTest)

            const rejectButton = findChild(controlUnderTest.footer, "rejectButton")
            verify(!!rejectButton)
            compare(rejectButton.interactive, true)

            rejectButton.clicked()
            compare(signalSpyRejected.count, 1)
            compare(controlUnderTest.opened, false)
            compare(controlUnderTest.result, Dialog.Rejected)
        }
    }
}
