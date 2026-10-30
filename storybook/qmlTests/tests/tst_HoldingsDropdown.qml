import QtQuick
import QtTest

import AppLayouts.Communities.controls
import AppLayouts.Communities.popups

Item {
    id: root

    width: 600
    height: 600

    readonly property string fooTokenKey: "10-0x0000000000000000000000000000000000000001"

    ListModel {
        id: assets

        Component.onCompleted: append({
            key: root.fooTokenKey, name: "Foo", symbol: "FOO", shortName: "FOO", decimals: 6,
            iconSource: "", category: TokenCategories.Category.General
        })
    }

    Component {
        id: dropdownComponent

        HoldingsDropdown {
            directParent: root
            assetsModel: assets
            collectiblesModel: ListModel {}
        }
    }

    TestCase {
        name: "HoldingsDropdown"
        when: windowShown

        function test_settingAnAssetKeyTakesTheRowsTokenData() {
            const dropdown = createTemporaryObject(dropdownComponent, root)
            verify(dropdown)

            dropdown.assetKey = root.fooTokenKey

            compare(dropdown.assetSymbol, "FOO")
            compare(dropdown.assetName, "Foo")
            compare(dropdown.assetDecimals, 6)
        }

        function test_resetClearsTheTokenData() {
            const dropdown = createTemporaryObject(dropdownComponent, root)
            dropdown.assetKey = root.fooTokenKey

            dropdown.reset()

            compare(dropdown.assetSymbol, "")
            compare(dropdown.assetName, "")
            compare(dropdown.assetDecimals, 0)
        }
    }
}
