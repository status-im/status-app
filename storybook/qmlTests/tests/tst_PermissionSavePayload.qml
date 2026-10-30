import QtQuick
import QtTest

import AppLayouts.Communities.controls
import AppLayouts.Communities.panels

import StatusQ.Core.Theme

import utils

Item {
    id: root

    width: 800
    height: 900

    function findByTypePrefix(item, prefix) {
        if (!item)
            return null
        if (item.toString().indexOf(prefix) === 0)
            return item
        const list = item.children
        for (let i = 0; i < list.length; ++i) {
            const found = findByTypePrefix(list[i], prefix)
            if (found)
                return found
        }
        return null
    }

    readonly property QtObject communityDetails: QtObject {
        readonly property string id: "test-community"
        readonly property string name: "Test Community"
        readonly property string image: ""
        readonly property string color: "red"
        readonly property bool owner: true
    }

    Component {
        id: panelComponent

        PermissionsSettingsPanel {
            width: root.width
            height: root.height

            permissionsModel: ListModel {}
            assetsModel: barAssets
            collectiblesModel: ListModel {}
            channelsModel: ListModel {}
            communityDetails: root.communityDetails
        }
    }

    readonly property string fooTokenKey: "10-0x0000000000000000000000000000000000000001"
    readonly property string barTokenKey: "1-0x0000000000000000000000000000000000000002"

    ListModel {
        id: barAssets

        Component.onCompleted: append({
            key: root.barTokenKey, name: "Bar", symbol: "BAR", shortName: "BAR", decimals: 18,
            iconSource: Assets.png("tokens/ENS"), category: TokenCategories.Category.General
        })
    }

    ListModel {
        id: fooCriteria

        Component.onCompleted: append({
            type: Constants.TokenType.ERC20, key: root.fooTokenKey,
            amount: "10000000", symbol: "FOO", name: "Foo", decimals: 6
        })
    }

    SignalSpy {
        id: updateSpy
        signalName: "updatePermissionRequested"
    }

    SignalSpy {
        id: createSpy
        signalName: "createPermissionRequested"
    }

    TestCase {
        name: "PermissionSavePayload"
        when: windowShown

        function test_assetCriterionCarriesItsOwnTokenData() {
            const panel = createTemporaryObject(panelComponent, root)
            verify(!!panel)
            panel.pushEditView({})
            const editView = root.findByTypePrefix(panel, "EditPermissionView")
            verify(!!editView)

            editView.dirtyValues.holdingsRequired = true
            editView.dirtyValues.selectedHoldingsModel.append({
                type: Constants.TokenType.ERC20,
                key: "1-0x744d70fdbe2ba4cf95131626614a1763df805b9e",
                amount: "10000000000000000000", symbol: "SNT", name: "Status", decimals: 18
            })

            createSpy.target = panel
            createSpy.clear()
            editView.createPermissionClicked()

            compare(createSpy.count, 1)
            const holding = createSpy.signalArguments[0][1][0]
            compare(holding.symbol, "SNT")
            compare(holding.name, "Status")
            compare(holding.decimals, 18)
        }

        function editPermission() {
            const panel = createTemporaryObject(panelComponent, root)
            verify(!!panel)
            panel.pushEditView({
                permissionKeyToEdit: "permission-1",
                holdingsToEditModel: fooCriteria,
                channelsToEditModel: channels,
                permissionTypeToEdit: PermissionTypes.Type.Member,
                isPrivateToEditValue: false
            })
            const editView = root.findByTypePrefix(panel, "EditPermissionView")
            verify(!!editView)
            tryCompare(editView.dirtyValues.selectedHoldingsModel, "count", 1)

            updateSpy.target = panel
            updateSpy.clear()
            return editView
        }

        function savedHolding(editView) {
            editView.saveChanges()
            compare(updateSpy.count, 1)
            compare(updateSpy.signalArguments[0][0], "permission-1")
            return updateSpy.signalArguments[0][2][0]
        }

        function test_editedCriterionKeepsItsOwnTokenData() {
            const editView = editPermission()

            const holding = savedHolding(editView)
            compare(holding.key, root.fooTokenKey)
            compare(holding.amount, "10000000")
            compare(holding.symbol, "FOO")
            compare(holding.name, "Foo")
            compare(holding.decimals, 6)
        }

        function test_switchedCriterionCarriesThePickedTokenData() {
            const editView = editPermission()
            const selector = findChild(editView, "tokensSelector")
            selector.itemClicked(selector, 0, { button: Qt.LeftButton, x: 0 })
            findChild(editView, "holdingsDropdown").updateAsset(root.barTokenKey, "5")

            const holding = savedHolding(editView)
            compare(holding.key, root.barTokenKey)
            compare(holding.amount, "5000000000000000000")
            compare(holding.symbol, "BAR")
            compare(holding.name, "Bar")
            compare(holding.decimals, 18)
        }
    }

    ListModel {
        id: channels
    }
}
