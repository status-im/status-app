import QtQuick
import QtTest

import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Chat.views
import AppLayouts.Profile.helpers
import shared.stores as SharedStores

Item {
    id: root
    width: 800
    height: 600

    property string openedChat
    property int openCount
    readonly property string ownKey: "0x04" + "ab".repeat(64)
    readonly property string ownCompressedKey: "zQ3shOwnKey"

    ListModel {
        id: contacts
        ListElement {
            pubKey: "other-key"
            displayName: "Alice"
            preferredDisplayName: "Alice"
            alias: "Alice"
            ensName: ""
            localNickname: ""
            compressedPubKey: ""
            usesDefaultName: false
            isEnsVerified: false
            isBlocked: false
            isVerified: false
            isUntrustworthy: false
            isContact: true
            thumbnailImage: ""
            icon: ""
            trustStatus: 0
            colorId: 0
            onlineStatus: 0
        }
    }

    CreateChatView {
        id: page
        anchors.fill: parent
        mutualContactsModel: contacts
        allContactsModel: contacts
        utilsStore: SharedStores.UtilsStore {
            function isChatKey(value) { return value === root.ownKey || value === root.ownCompressedKey }
        }
        createChatPropertiesStore: ChatStores.CreateChatPropertiesStore {}
        rootStore: ChatStores.RootStore {
            contactsStore: QtObject {
                signal resolvedENS(string publicKey, string address, string uuid)
                function joinPrivateChat(key) {
                    root.openedChat = key
                    root.openCount++
                }
            }
        }
        selfContact: ContactDetails {
            publicKey: root.ownKey
            compressedPubKey: root.ownCompressedKey
            preferredDisplayName: "Alice Self"
        }
    }

    TestCase {
        name: "CreateChatSelfContact"
        when: windowShown

        property var selector
        property var selfRow

        function init() {
            selector = findChild(page, "createChatMembersSelector")
            selfRow = findChild(page, "createChatSelfContact")
            verify(!!selector)
            verify(!!selfRow)
            selector.cleanup()
            selector.edit.forceActiveFocus()
            root.openedChat = ""
            root.openCount = 0
        }

        function test_search() {
            selector.edit.text = "Self"
            tryCompare(selfRow, "visible", true)
            tryCompare(selector.suggestionsDialog, "visible", false)
            keyClick(Qt.Key_Return)
            compare(root.openedChat, root.ownKey)
            compare(root.openCount, 1)
        }

        function test_suggestions() {
            selector.edit.text = "Alice"
            tryCompare(selfRow, "visible", true)
            tryCompare(selector.suggestionsDialog, "visible", true)
            tryCompare(selector.suggestionsModel, "count", 1)
            keyClick(Qt.Key_Return)
            compare(root.openCount, 0)
            compare(selector.model.count, 1)
            compare(selector.model.get(0).pubKey, "other-key")
            compare(selfRow.visible, false)

            selector.cleanup()
            selector.edit.text = "No match"
            tryCompare(selfRow, "visible", false)
            tryCompare(selector.suggestionsDialog, "visible", true)
            tryCompare(selector.suggestionsModel, "count", 0)
        }

        function test_compressedKeyIsCaseSensitive() {
            selector.edit.text = root.ownCompressedKey.toLowerCase()
            tryCompare(selfRow, "visible", false)
            tryCompare(selector.suggestionsDialog, "visible", true)
            keyClick(Qt.Key_Return)
            compare(root.openCount, 0)
        }

        function test_key_data() {
            return [
                {tag: "full typed", key: root.ownKey, pasted: false},
                {tag: "compressed typed", key: root.ownCompressedKey, pasted: false},
                {tag: "full pasted", key: root.ownKey, pasted: true},
                {tag: "compressed pasted", key: root.ownCompressedKey, pasted: true}
            ]
        }

        function test_key(data) {
            selector.edit.text = data.key
            if (data.pasted) {
                selector.suggestionsDialog.forceHide = true
                selector.textPasted(data.key)
            } else {
                wait(400)
            }
            tryCompare(selfRow, "visible", true)
            tryCompare(selector.suggestionsDialog, "visible", false)
            compare(selector.model.count, 0)
            if (data.pasted)
                mouseClick(selfRow)
            else
                keyClick(Qt.Key_Enter)
            compare(root.openedChat, root.ownKey)
            compare(root.openCount, 1)
        }
    }
}
