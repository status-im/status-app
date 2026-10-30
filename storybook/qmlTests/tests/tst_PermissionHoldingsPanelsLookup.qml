import QtQuick
import QtTest

import AppLayouts.Communities.controls
import AppLayouts.Communities.panels

import utils

Item {
    id: root

    width: 800
    height: 600

    readonly property string sntTokenKey: "1-0x744d70fdbe2ba4cf95131626614a1763df805b9e"

    // saved without token data and absent from assetsModel
    function createLegacyPermissions() {
        const permissions = Qt.createQmlObject("import QtQuick; ListModel {}", root)
        permissions.append({
            key: "p1",
            permissionType: PermissionTypes.Type.Member,
            permissionState: PermissionTypes.State.Approved,
            isPrivate: false,
            tokenCriteriaMet: false,
            holdingsListModel: [{
                type: Constants.TokenType.ERC20, key: root.sntTokenKey,
                amount: "10000000000000000000", symbol: "", name: "", decimals: 0,
                available: false
            }],
            channelsListModel: []
        })
        return permissions
    }

    ListModel { id: emptyAssets }
    ListModel { id: emptyCollectibles }

    function sntLookup(key) {
        if (key === root.sntTokenKey)
            return { key, symbol: "SNT", name: "Status", decimals: 18, logoUri: "" }
        return { key: "", symbol: "", name: "", decimals: 0, logoUri: "" }
    }

    Component {
        id: qualificationPanelComponent

        ChatPermissionQualificationPanel {
            width: 500
            height: 40
            assetsModel: ListModel {}
            collectiblesModel: ListModel {}
            getTokenByKeyOrGroupKeyFromAllTokens: root.sntLookup
        }
    }

    // not exported by the panels module
    readonly property Component holdingsListPanelComponent: Qt.createComponent(
        Qt.resolvedUrl("../../../ui/app/AppLayouts/Communities/panels/HoldingsListPanel.qml"))
    readonly property Component sharedAddressesPanelComponent: Qt.createComponent(
        Qt.resolvedUrl("../../../ui/app/AppLayouts/Communities/panels/SharedAddressesPermissionsPanel.qml"))

    TestCase {
        name: "PermissionHoldingsPanelsLookup"
        when: windowShown

        function findItemWithText(item, text) {
            if (!item)
                return null
            if (item.title === text || item.text === text)
                return item
            const children = item.children ?? []
            for (let i = 0; i < children.length; i++) {
                const found = findItemWithText(children[i], text)
                if (found)
                    return found
            }
            if (item.contentItem && item.contentItem !== item && children.indexOf(item.contentItem) === -1)
                return findItemWithText(item.contentItem, text)
            return null
        }

        function test_holdingsListPanelLooksUpALegacyCriterion() {
            const panel = createTemporaryObject(root.holdingsListPanelComponent, root, {
                assetsModel: emptyAssets, collectiblesModel: emptyCollectibles,
                getTokenByKeyOrGroupKeyFromAllTokens: root.sntLookup,
                model: createLegacyPermissions()
            })
            verify(panel)
            tryVerify(() => !!findItemWithText(panel, "10 SNT"))
        }

        function test_qualificationPanelLooksUpALegacyCriterion() {
            const panel = createTemporaryObject(qualificationPanelComponent, root,
                                                { holdingsModel: createLegacyPermissions() })
            verify(panel)
            tryVerify(() => !!findItemWithText(panel, "10 SNT"))
        }

        function test_sharedAddressesPanelLooksUpALegacyCriterion() {
            const panel = createTemporaryObject(root.sharedAddressesPanelComponent, root, {
                width: 500, eligibleToJoinAs: PermissionTypes.Type.Member,
                assetsModel: emptyAssets, collectiblesModel: emptyCollectibles,
                getTokenByKeyOrGroupKeyFromAllTokens: root.sntLookup,
                permissionsModel: createLegacyPermissions()
            })
            verify(panel)
            tryVerify(() => !!findItemWithText(panel, "10 SNT"))
        }
    }
}
