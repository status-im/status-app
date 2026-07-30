import QtQuick
import QtTest

import AppLayouts.Profile.views.wallet

import StatusQ.Core.Theme

import utils

Item {
    id: root

    width: 600
    height: 600

    ListModel {
        id: accountsModel
    }

    Component {
        id: componentUnderTest

        AccountOrderView {
            objectName: "accountOrderView"
        }
    }

    SignalSpy {
        id: moveAccountRequestedSpy
        signalName: "moveAccountRequested"
    }

    SignalSpy {
        id: moveAccountFinallyRequestedSpy
        signalName: "moveAccountFinallyRequested"
    }

    TestCase {
        name: "AccountOrderView"
        when: windowShown

        property var controlUnderTest: null

        readonly property string lonelyText:
            "This account looks a little lonely. Add another account to enable re-ordering."

        function account(name, emoji, colorId, position) {
            return {
                name,
                address: "0x%1".arg(position.toString().padStart(40, "0")),
                emoji,
                colorId,
                position,
                walletType: "",
                migratedToColdWallet: false
            }
        }

        function cleanup() {
            if (!!controlUnderTest)
                controlUnderTest.destroy()
            controlUnderTest = null
            moveAccountRequestedSpy.clear()
            moveAccountFinallyRequestedSpy.clear()
        }

        function verifyOrder(expectedTitles) {
            for (let i = 0; i < expectedTitles.length; ++i)
                tryCompare(delegateAt(i), "title", expectedTitles[i])
        }

        function delegateAt(index) {
            return findChild(controlUnderTest, "accountOrderDelegate-%1".arg(index))
        }

        function createView(accountData) {
            cleanup()

            accountsModel.clear()
            for (let i = 0; i < accountData.length; ++i)
                accountsModel.append(accountData[i])

            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                width: root.width,
                accountsModel: accountsModel
            })
            controlUnderTest.moveAccountRequested.connect(function(from, to) {
                accountsModel.move(from, to, 1)
            })
            verify(!!controlUnderTest)

            moveAccountRequestedSpy.target = controlUnderTest
            moveAccountFinallyRequestedSpy.target = controlUnderTest

            waitForRendering(controlUnderTest)

            compare(accountsModel.count, accountData.length)

            const accountsList = findChild(controlUnderTest, "accountOrderList")
            verify(!!accountsList)
            tryCompare(accountsList, "count", accountData.length)
        }

        function test_changeAccountOrderByDragAndDrop() {
            createView([
                account("Account 1", "😀", Constants.walletAccountColors.primary, 0),
                account("Generated 1", "😎", Constants.walletAccountColors.army, 1),
                account("Generated 2", "👍", Constants.walletAccountColors.magenta, 2)
            ])

            verifyOrder(["Account 1", "Generated 1", "Generated 2"])
            compare(delegateAt(1).icon.name, "😎")
            compare(delegateAt(2).icon.name, "👍")
            compare(delegateAt(1).icon.color,
                    Utils.getColorForId(Theme.palette, Constants.walletAccountColors.army))
            compare(delegateAt(2).icon.color,
                    Utils.getColorForId(Theme.palette, Constants.walletAccountColors.magenta))

            let delegate = delegateAt(0)
            waitForRendering(delegate)
            mouseDrag(delegate, delegate.width / 2, delegate.height / 2,
                      0, delegate.height * 2)

            verifyOrder(["Generated 1", "Generated 2", "Account 1"])
            verify(moveAccountRequestedSpy.count > 0)
            compare(moveAccountFinallyRequestedSpy.count, 1)
            compare(moveAccountFinallyRequestedSpy.signalArguments[0][0], 0)
            compare(moveAccountFinallyRequestedSpy.signalArguments[0][1], 2)

            const moveCallsAfterFirstDrag = moveAccountRequestedSpy.count
            moveAccountFinallyRequestedSpy.clear()

            delegate = delegateAt(1)
            waitForRendering(delegate)
            mouseDrag(delegate, delegate.width / 2, delegate.height / 2,
                      0, -delegate.height)

            verifyOrder(["Generated 2", "Generated 1", "Account 1"])
            verify(moveAccountRequestedSpy.count > moveCallsAfterFirstDrag)
            compare(moveAccountFinallyRequestedSpy.count, 1)
            compare(moveAccountFinallyRequestedSpy.signalArguments[0][0], 1)
            compare(moveAccountFinallyRequestedSpy.signalArguments[0][1], 0)
        }

        function test_changeAccountOrderNotPossible() {
            createView([
                account("Account 1", "😀", Constants.walletAccountColors.primary, 0)
            ])

            const recommendation = findChild(controlUnderTest, "accountOrderRecommendation")
            verify(!!recommendation)
            compare(recommendation.text, lonelyText)

            const delegate = delegateAt(0)
            verify(!!delegate)
            compare(delegate.title, "Account 1")
            compare(delegate.draggable, false)

            mouseDrag(delegate, delegate.width / 2, delegate.height / 2,
                      0, delegate.height)

            compare(delegateAt(0).title, "Account 1")
            compare(moveAccountRequestedSpy.count, 0)
            compare(moveAccountFinallyRequestedSpy.count, 0)
        }
    }
}
