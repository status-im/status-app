// Mock of src/app/modules/main/wallet_section/saved_addresses/view.nim
import QtQuick

QtObject {
    id: root

    readonly property string contextPropertyName: "walletSectionSavedAddresses"

    // name / address / mixedcaseAddress / ens / colorId / isTest
    property ListModel model: ListModel {}

    property int capacity: 20

    signal savedAddressAddedOrUpdated(bool added, string name, string address, string errorMsg)
    signal savedAddressDeleted(string name, string address, string errorMsg)

    function _indexOf(address) {
        for (let i = 0; i < root.model.count; ++i) {
            if (root.model.get(i).address === address)
                return i
        }
        return -1
    }

    function createOrUpdateSavedAddress(name, address, ens, colorId) {
        const index = _indexOf(address)
        const added = index === -1
        if (added) {
            root.model.append({
                name: name, address: address, mixedcaseAddress: address,
                ens: ens, colorId: colorId, isTest: false
            })
        } else {
            root.model.setProperty(index, "name", name)
            root.model.setProperty(index, "ens", ens)
            root.model.setProperty(index, "colorId", colorId)
        }
        root.savedAddressAddedOrUpdated(added, name, address, "")
    }

    function deleteSavedAddress(address) {
        const index = _indexOf(address)
        if (index === -1) {
            root.savedAddressDeleted("", address, "not found")
            return
        }
        const name = root.model.get(index).name
        root.model.remove(index)
        root.savedAddressDeleted(name, address, "")
    }

    function savedAddressNameExists(name) {
        for (let i = 0; i < root.model.count; ++i) {
            if (root.model.get(i).name === name)
                return true
        }
        return false
    }

    function getSavedAddressAsJson(address) {
        const index = _indexOf(address)
        if (index === -1)
            return "null"
        const row = root.model.get(index)
        return JSON.stringify({
            name: row.name, address: row.address, ens: row.ens,
            colorId: row.colorId, isTest: row.isTest
        })
    }

    function remainingCapacityForSavedAddresses() {
        return Math.max(0, root.capacity - root.model.count)
    }
}
