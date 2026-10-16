import QtQuick
import QtTest

import AppLayouts.Communities.views
import utils

Item {
    id: root
    width: 800
    height: 900

    ListModel {
        id: collectibles
        ListElement {
            key: "socks"
            name: "Socks"
            symbol: "SOCK"
            iconSource: ""
            chainId: 560048
            chainName: "Hoodi"
            chainIcon: "network/ethereum"
            remainingSupply: "10"
            multiplierIndex: 0
            infiniteSupply: false
            contractUniqueKey: "560048_0xcollectible"
            accountName: "Status account"
        }
    }

    ListModel {
        id: accountsModel
        ListElement {
            name: "Status account"
            address: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240"
            color: "red"
            emoji: "🔑"
            walletType: "generated"
            keyUid: "uid"
            migratedToColdWallet: false
        }
    }

    Component {
        id: componentUnderTest
        EditAirdropView {
            width: root.width
            height: root.height
            communityDetails: QtObject {
                readonly property string id: "community"
                readonly property string name: "Test Community"
                readonly property string image: ""
                readonly property string color: "red"
                readonly property bool owner: true
            }
            assetsModel: ListModel {}
            collectiblesModel: collectibles
            membersModel: ListModel {}
            accountsModel: accountsModel
            totalFeeText: "0.01 ETH"
            feeErrorText: ""
            feesPerSelectedContract: [
                { contractUniqueKey: "560048_0xcollectible", feeText: "0.01 ETH" }
            ]
            feesAvailable: true
            enabledChainIds: "560048"
        }
    }

    SignalSpy {
        id: airdropSpy
        signalName: "airdropClicked"
    }

    TestCase {
        name: "EditAirdropView"
        when: windowShown

        function init() {
            airdropSpy.clear()
        }

        function test_select_token_and_address_enables_airdrop() {
            const view = createTemporaryObject(componentUnderTest, root)
            verify(!!view)
            waitForRendering(view)
            airdropSpy.target = view

            view.selectToken("socks", "1", Constants.TokenType.ERC721)
            view.addAddresses(["0x7F47C2e98a4BBf5487E6fb082eC2D9Ab0E6d8888"])
            waitForRendering(view)

            compare(view.selectedAddressesToAirdrop.length, 1)
            const createButton = findChild(view, "createAirdropButton")
            verify(!!createButton)
            compare(createButton.enabled, true)
        }
    }
}
