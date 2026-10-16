import QtQuick
import QtTest

import AppLayouts.Communities.views

import utils

Item {
    id: root
    width: 800
    height: 900

    ListModel {
        id: accountsModel
        ListElement {
            name: "Status account"
            address: "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240"
            color: "red"
            emoji: "🔑"
            walletType: "generated"
        }
    }

    Component {
        id: collectibleComponent
        EditCommunityTokenView {
            width: root.width
            height: root.height
            isAssetView: false
            accounts: accountsModel
            tokensModel: ListModel {}
            referenceTokenGroupsModel: ListModel {}
            token.chainName: "Hoodi"
            feeText: "0.01 ETH"
            feeErrorText: ""
            isFeeLoading: false
        }
    }

    Component {
        id: assetComponent
        EditCommunityTokenView {
            width: root.width
            height: root.height
            isAssetView: true
            accounts: accountsModel
            tokensModel: ListModel {}
            referenceTokenGroupsModel: ListModel {}
            token.chainName: "Hoodi"
            feeText: "0.01 ETH"
            feeErrorText: ""
            isFeeLoading: false
        }
    }

    TestCase {
        name: "EditCommunityTokenView"
        when: windowShown

        function test_collectible_switches_and_fee_label() {
            const view = createTemporaryObject(collectibleComponent, root)
            verify(!!view)
            waitForRendering(view)

            compare(view.feeLabel, "Mint collectible on Hoodi")
            verify(!!findChild(view, "editCommunityTokenRemotelyDestructSwitch"))
            verify(!!findChild(view, "editCommunityTokenTransferableSwitch"))
            const preview = findChild(view, "editCommunityTokenPreviewButton")
            verify(!!preview)
            compare(preview.enabled, false)
        }

        function test_asset_hides_destructible_switch_and_fee_label() {
            const view = createTemporaryObject(assetComponent, root)
            verify(!!view)
            waitForRendering(view)

            compare(view.feeLabel, "Mint asset on Hoodi")
            const destructSwitch = findChild(view, "editCommunityTokenRemotelyDestructSwitch")
            verify(!!destructSwitch)
            compare(destructSwitch.visible, false)
        }
    }
}
