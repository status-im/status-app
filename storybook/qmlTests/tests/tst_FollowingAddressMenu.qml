import QtQuick
import QtTest

import AppLayouts.Wallet.controls
import AppLayouts.Wallet.stores as WalletStores

Item {
    id: root
    width: 400
    height: 400

    Component {
        id: menuComponent

        FollowingAddressMenu {
            rootStore: WalletStores.RootStore
            activeNetworksModel: []
        }
    }

    TestCase {
        name: "FollowingAddressMenu"
        when: windowShown

        function test_openMenu_setsFieldsAndSavedAddressAction() {
            const menu = createTemporaryObject(menuComponent, root)
            const action = findChild(menu, "addToSavedAddressesAction")
            verify(action)

            menu.openMenu(root, 0, 0, {
                name: "saved.eth",
                address: "0x0000000000000000000000000000000000000042",
                ensName: "saved.eth",
                tags: ["ens"]
            })

            compare(menu.name, "saved.eth")
            compare(action.text, qsTr("Remove from saved addresses"))

            menu.openMenu(root, 0, 0, {
                name: "0xdef",
                address: "0xdef",
                ensName: "",
                tags: []
            })

            compare(action.text, qsTr("Add to saved addresses"))
        }
    }
}
