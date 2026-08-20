import QtQuick
import QtTest

import AppLayouts.Profile.popups

Item {
    id: root
    width: 640
    height: 520

    QtObject {
        id: accountsModuleStub
        property var takenNames: ["Taken"]
        property var lastRename: []

        function keypairNameExists(name) {
            return takenNames.indexOf(name) !== -1
        }

        function renameKeypair(keyUid, name) {
            lastRename = [keyUid, name]
        }
    }

    Component {
        id: popupComponent
        RenameKeypairPopup {
            destroyOnClose: false
            keyUid: "seed-key-uid"
            name: "Imported key pair"
            accounts: ListModel {}
            accountsModule: accountsModuleStub
        }
    }

    TestCase {
        name: "RenameKeypairPopup"
        when: windowShown

        function openPopup() {
            accountsModuleStub.lastRename = []
            const popup = createTemporaryObject(popupComponent, root)
            verify(!!popup)
            popup.open()
            tryCompare(popup, "opened", true)
            return popup
        }

        function nameInput(popup) {
            const input = findChild(popup, "renameKeypairNameInput")
            verify(!!input)
            return input
        }

        function saveButton(popup) {
            const button = findChild(popup, "saveRenameKeypairChangesButton")
            verify(!!button)
            return button
        }

        function test_sameName_saveDisabled() {
            const popup = openPopup()
            verify(!saveButton(popup).enabled)
            popup.close()
        }

        function test_duplicateName_saveDisabled() {
            const popup = openPopup()
            nameInput(popup).text = "Taken"
            tryCompare(nameInput(popup).errorMessageCmp, "text", qsTr("Key pair name already in use"))
            verify(!saveButton(popup).enabled)
            popup.close()
        }

        function test_newName_callsRenameKeypair() {
            const popup = openPopup()
            nameInput(popup).text = "New name"
            tryCompare(saveButton(popup), "enabled", true)
            mouseClick(saveButton(popup))
            compare(accountsModuleStub.lastRename, ["seed-key-uid", "New name"])
        }
    }
}
