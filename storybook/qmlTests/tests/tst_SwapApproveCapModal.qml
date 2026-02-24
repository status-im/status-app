import QtQuick
import QtQuick.Controls
import QtTest
import QtQml

import Models

import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Theme

import AppLayouts.Wallet
import AppLayouts.Wallet.popups.swap

import utils

Item {
    id: root
    width: 600
    height: 400

    Component {
        id: componentUnderTest
        SwapApproveCapModal {
            anchors.centerIn: parent
            formatBigNumber: (number, symbol, noSymbolOption) => parseFloat(number).toLocaleString(Qt.locale(), 'f', 2) + (noSymbolOption ? "" : " " + symbol)

            fromTokenSymbol: "DAI"
            fromTokenAmount: "100.07"
            fromTokenContractAddress: "0x6B175474E89094C44Da98b954EedeAC495271d0F"

            accountName: "Hot wallet (generated)"
            accountAddress: "0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8881"
            accountEmoji: "🚗"
            accountColor: Utils.getColorForId(Theme.palette, Constants.walletAccountColors.primary)
            accountBalanceFormatted: "120.55489 DAI"

            networkShortName: Constants.networkShortChainNames.mainnet
            networkName: "Mainnet"
            networkIconPath: Assets.svg("network/Network=Ethereum")
            networkBlockExplorerUrl: "https://etherscan.io/"
            networkChainId: 1

            fiatFees: "1.54 USD"
            cryptoFees: "0.001 ETH"
            estimatedTime: Constants.TransactionEstimatedTime.Unknown

            loginType: Constants.LoginType.Password
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

    property SwapApproveCapModal controlUnderTest: null

    TestCase {
        name: "SwapApproveCapModal"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)

            // Open the dialog and wait until it is fully initialized so geometry bindings resolve correctly
            verify(!!controlUnderTest)
            controlUnderTest.open()
            tryVerify(() => controlUnderTest.opened === true, 1000)

            signalSpyAccepted.clear()
            signalSpyRejected.clear()
        }

        function test_basicGeometry() {
            verify(!!controlUnderTest)
            verify(controlUnderTest.width > 0)
            verify(controlUnderTest.height > 0)
        }

        function test_fromToProps() {
            verify(!!controlUnderTest)
            controlUnderTest.fromTokenSymbol = "SNT"
            controlUnderTest.fromTokenAmount = "1000.123456789"
            controlUnderTest.fromTokenContractAddress = "Oxdeadbeef"

            // title & subtitle
            compare(controlUnderTest.title, qsTr("Approve spending cap"))
            compare(controlUnderTest.subtitle, controlUnderTest.serviceProviderHostname)

            // info box
            const headerText = findChild(controlUnderTest.contentItem, "headerText")
            verify(!!headerText)
            compare(headerText.text, qsTr("Set %1 spending cap in %2 for %3 on %4")
                    .arg(controlUnderTest.formatBigNumber(controlUnderTest.fromTokenAmount, controlUnderTest.fromTokenSymbol))
                    .arg(controlUnderTest.accountName).arg(controlUnderTest.serviceProviderHostname).arg(controlUnderTest.networkName))

            const fromImage = findChild(controlUnderTest.contentItem, "fromImageIdenticon")
            verify(!!fromImage)
            compare(fromImage.visible, true)
            compare(fromImage.asset.emoji, controlUnderTest.accountEmoji)
            compare(fromImage.asset.color, controlUnderTest.accountColor)
            const toImage = findChild(controlUnderTest.contentItem, "toImageIdenticon")
            verify(!!toImage)
            compare(toImage.asset.name, Constants.tokenIcon(controlUnderTest.fromTokenSymbol))

            // spending cap box
            const spendingCapBox = findChild(controlUnderTest.contentItem, "spendingCapBox")
            verify(!!spendingCapBox)
            compare(spendingCapBox.caption, qsTr("Set spending cap"))
            compare(spendingCapBox.primaryText, controlUnderTest.formatBigNumber(controlUnderTest.fromTokenAmount, root.fromTokenSymbol, {noSymbol: true}))
        }

        function test_accountInfo() {
            verify(!!controlUnderTest)

            // account box
            const accountBox = findChild(controlUnderTest.contentItem, "accountBox")
            verify(!!accountBox)

            compare(accountBox.caption, qsTr("Account"))
            compare(accountBox.primaryText, controlUnderTest.accountName)
            compare(accountBox.secondaryText, SQUtils.Utils.elideAndFormatWalletAddress(controlUnderTest.accountAddress))
            compare(accountBox.asset.emoji, controlUnderTest.accountEmoji)
            compare(accountBox.asset.color, controlUnderTest.accountColor)
        }

        function test_tokenInfo_data() {
            return [
                        {tag: "ETH", fromTokenSymbol: "ETH"},
                        {tag: "DAI", fromTokenSymbol: "DAI"},
                    ]
        }

        function test_tokenInfo(data) {
            verify(!!controlUnderTest)
            controlUnderTest.fromTokenSymbol = data.fromTokenSymbol

            // token box
            const tokenBox = findChild(controlUnderTest.contentItem, "tokenBox")
            verify(!!tokenBox)

            compare(tokenBox.caption, qsTr("Token"))
            compare(tokenBox.primaryText, controlUnderTest.fromTokenSymbol)
            compare(tokenBox.secondaryText,
                    controlUnderTest.fromTokenSymbol === "ETH" ? ""
                                                               : SQUtils.Utils.elideAndFormatWalletAddress(controlUnderTest.fromTokenContractAddress))
            compare(tokenBox.icon, Constants.tokenIcon(controlUnderTest.fromTokenSymbol))
            compare(tokenBox.badge, controlUnderTest.networkIconPath)
        }

        function test_smartContractInfo() {
            verify(!!controlUnderTest)

            // smart contract box
            const smartContractBox = findChild(controlUnderTest.contentItem, "smartContractBox")
            verify(!!smartContractBox)

            compare(smartContractBox.caption, qsTr("Via smart contract"))
            compare(smartContractBox.primaryText, controlUnderTest.serviceProviderName)
            compare(smartContractBox.secondaryText, SQUtils.Utils.elideAndFormatWalletAddress(controlUnderTest.serviceProviderContractAddress))
            compare(smartContractBox.icon, Assets.png("swap/paraswap"))
        }

        function test_networkInfo() {
            verify(!!controlUnderTest)

            // network box
            const networkBox = findChild(controlUnderTest.contentItem, "networkBox")
            verify(!!networkBox)

            compare(networkBox.caption, qsTr("Network"))
            compare(networkBox.primaryText, controlUnderTest.networkName)
            compare(networkBox.icon, controlUnderTest.networkIconPath)
        }

        function test_feesInfo() {
            verify(!!controlUnderTest)

            // fees box
            const feesBox = findChild(controlUnderTest.contentItem, "feesBox")
            verify(!!feesBox)

            compare(feesBox.caption, qsTr("Fees"))
            compare(feesBox.primaryText, qsTr("Max. fees on %1").arg(controlUnderTest.networkName))

            const fiatFeesText = findChild(feesBox, "fiatFeesText")
            verify(!!fiatFeesText)
            compare(fiatFeesText.text, controlUnderTest.fiatFees)

            const cryptoFeesText = findChild(feesBox, "cryptoFeesText")
            verify(!!cryptoFeesText)
            compare(cryptoFeesText.text, controlUnderTest.cryptoFees)
        }

        function test_loginType_data() {
            return [
                { tag: "password", loginType: Constants.LoginType.Password, iconName: "password" },
                { tag: "touchId", loginType: Constants.LoginType.Biometrics, iconName: "touch-id" },
                { tag: "keycard", loginType: Constants.LoginType.Keycard, iconName: "keycard" }
            ]
        }

        function test_loginType(data) {
            const loginType = data.loginType
            const iconName = data.iconName

            verify(!!controlUnderTest)

            controlUnderTest.loginType = loginType

            const signButton = findChild(controlUnderTest.footer, "signButton")
            verify(!!signButton)
            compare(signButton.icon.name, iconName)
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

            const footerEstimatedTime = findChild(controlUnderTest.footer, "footerEstimatedTime")
            verify(!!footerEstimatedTime)
            compare(footerEstimatedTime.loading, false)

            const fiatFeesText = findChild(controlUnderTest.contentItem, "fiatFeesText")
            verify(!!fiatFeesText)
            compare(fiatFeesText.loading, false)

            const cryptoFeesText = findChild(controlUnderTest.contentItem, "cryptoFeesText")
            verify(!!cryptoFeesText)
            compare(cryptoFeesText.loading, false)

            controlUnderTest.feesLoading = true

            compare(signButton.interactive, false)
            compare(footerFiatFeesText.loading, true)
            compare(footerEstimatedTime.loading, true)
            compare(fiatFeesText.loading, true)
            compare(cryptoFeesText.loading, true)
        }

        function test_footerInfo() {
            verify(!!controlUnderTest)

            const fiatFeesText = findChild(controlUnderTest.footer, "footerFiatFeesText")
            verify(!!fiatFeesText)
            compare(fiatFeesText.text, controlUnderTest.fiatFees)

            const footerEstimatedTime = findChild(controlUnderTest.footer, "footerEstimatedTime")
            verify(!!footerEstimatedTime)
            compare(footerEstimatedTime.text, WalletUtils.getLabelForEstimatedTxTime(controlUnderTest.estimatedTime))
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
