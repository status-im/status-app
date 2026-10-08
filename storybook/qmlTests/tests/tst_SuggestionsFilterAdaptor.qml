import QtQuick
import QtTest

import AppLayouts.Chat.adaptors
import StatusQ.Core.Utils as SQUtils

Item {
    id: root

    ListModel {
        id: usersModel

        ListElement {
            pubKey: "0xbob"
            preferredDisplayName: "bob"
        }
        ListElement {
            pubKey: "0xalice"
            preferredDisplayName: "Alice"
        }
        ListElement {
            pubKey: "0xeve"
            preferredDisplayName: "Eve"
        }
    }

    ListModel {
        id: emptyModel
    }

    Component {
        id: adaptorComponent

        SuggestionsFilterAdaptor {
            sourceModel: usersModel
        }
    }

    TestCase {
        name: "SuggestionsFilterAdaptor"
        when: windowShown

        function keys(adaptor) {
            return SQUtils.ModelUtils.modelToArray(adaptor.model, ["pubKey"])
                .map(row => row.pubKey)
        }

        function test_initialInclusion_data() {
            return [
                { tag: "included", includeEveryone: true,
                  expected: ["0x00001", "0xalice", "0xbob", "0xeve"] },
                { tag: "excluded", includeEveryone: false,
                  expected: ["0xalice", "0xbob", "0xeve"] }
            ]
        }

        function test_initialInclusion(data) {
            const adaptor = createTemporaryObject(adaptorComponent, root, {
                usersModelIncludeAtEveryone: data.includeEveryone
            })
            verify(adaptor)
            tryVerify(() => JSON.stringify(keys(adaptor)) === JSON.stringify(data.expected))
        }

        function test_inclusionChanges_data() {
            return [
                { tag: "initially-included", includeEveryone: true },
                { tag: "initially-excluded", includeEveryone: false }
            ]
        }

        function test_inclusionChanges(data) {
            const adaptor = createTemporaryObject(adaptorComponent, root, {
                usersModelIncludeAtEveryone: data.includeEveryone
            })
            verify(adaptor)
            for (let i = 0; i < 4; ++i) {
                adaptor.usersModelIncludeAtEveryone = i % 2 === 0
                const expected = adaptor.usersModelIncludeAtEveryone
                    ? ["0x00001", "0xalice", "0xbob", "0xeve"]
                    : ["0xalice", "0xbob", "0xeve"]
                tryVerify(() => JSON.stringify(keys(adaptor)) === JSON.stringify(expected))
            }
        }

        function test_filtering() {
            const adaptor = createTemporaryObject(adaptorComponent, root)
            verify(adaptor)
            adaptor.filter = "EV"
            tryVerify(() => JSON.stringify(keys(adaptor)) === '["0x00001","0xeve"]')

            adaptor.usersModelIncludeAtEveryone = false
            tryVerify(() => JSON.stringify(keys(adaptor)) === '["0xeve"]')

            adaptor.filter = "zzz"
            tryVerify(() => keys(adaptor).length === 0)
        }

        function test_withoutUsers_data() {
            return [
                { tag: "null", users: null },
                { tag: "empty", users: emptyModel }
            ]
        }

        function test_withoutUsers(data) {
            const adaptor = createTemporaryObject(adaptorComponent, root, {
                sourceModel: data.users
            })
            verify(adaptor)
            tryVerify(() => JSON.stringify(keys(adaptor)) === '["0x00001"]')
            adaptor.usersModelIncludeAtEveryone = false
            tryVerify(() => keys(adaptor).length === 0)
        }
    }
}
