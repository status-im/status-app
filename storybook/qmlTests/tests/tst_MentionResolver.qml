import QtQuick
import QtTest

import shared.status

Item {
    id: root
    width: 200
    height: 200

    ListModel {
        id: usersModel
    }

    MentionResolver {
        id: resolver
        sourceModel: usersModel
    }

    TestCase {
        name: "MentionResolver"
        when: windowShown

        function init() {
            usersModel.clear()
        }

        // The "everyone" system tag is always resolvable, even with no source rows.
        function test_everyoneAlwaysPresent() {
            compare(resolver.map["0x00001"], "everyone")
        }

        // The map is built from the source model's pub-key/name roles.
        function test_buildsFromModel() {
            usersModel.append({ pubKey: "0xAAA", name: "Alice" })
            usersModel.append({ pubKey: "0xBBB", name: "Bob" })

            compare(resolver.map["0xAAA"], "Alice")
            compare(resolver.map["0xBBB"], "Bob")
            compare(resolver.map["0x00001"], "everyone")
        }

        // An unknown pub key is simply absent (renderer falls back to the raw key).
        function test_unknownKeyAbsent() {
            usersModel.append({ pubKey: "0xAAA", name: "Alice" })
            verify(resolver.map["0xCCC"] === undefined)
        }

        // A rename in the source model updates the map reactively.
        function test_reactiveToNameChange() {
            usersModel.append({ pubKey: "0xAAA", name: "Alice" })
            compare(resolver.map["0xAAA"], "Alice")

            usersModel.setProperty(0, "name", "Alicia")
            compare(resolver.map["0xAAA"], "Alicia")
        }

        // Adding / removing rows updates the map reactively.
        function test_reactiveToInsertAndRemove() {
            usersModel.append({ pubKey: "0xAAA", name: "Alice" })
            compare(resolver.map["0xAAA"], "Alice")

            usersModel.remove(0)
            verify(resolver.map["0xAAA"] === undefined)
        }

        // Custom role names are honoured.
        function test_customRoleNames() {
            const m = createTemporaryObject(customResolverComp, root)
            verify(m)
            m.sourceModel.append({ id: "0xDDD", label: "Dave" })
            compare(m.map["0xDDD"], "Dave")
        }

        Component {
            id: customResolverComp
            MentionResolver {
                pubKeyRole: "id"
                nameRole: "label"
                sourceModel: ListModel {}
            }
        }
    }
}
