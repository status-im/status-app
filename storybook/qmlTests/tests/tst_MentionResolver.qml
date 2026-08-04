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

    SignalSpy {
        id: mapSpy
        target: resolver
        signalName: "mapChanged"
    }

    TestCase {
        name: "MentionResolver"
        when: windowShown

        function init() {
            usersModel.clear()
            resolver.enabled = true
            mapSpy.clear()
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

        // The map is rebuilt only when the display-name role changes, not for unrelated roles.
        // (map is a `var` returning a fresh object per rebuild, so mapChanged fires per rebuild.)
        function test_rebuildsOnlyForNameRole() {
            usersModel.append({ pubKey: "0xAAA", name: "Alice", online: false })
            compare(resolver.map["0xAAA"], "Alice") // force the initial build

            mapSpy.clear()
            usersModel.setProperty(0, "online", true)   // non-name role → no rebuild
            compare(mapSpy.count, 0)

            usersModel.setProperty(0, "name", "Alicia") // name role → rebuild
            verify(mapSpy.count > 0)
            compare(resolver.map["0xAAA"], "Alicia")
        }

        // Disabled: source-model changes don't rebuild the map; it holds the last value.
        function test_disabledFreezesMap() {
            usersModel.append({ pubKey: "0xAAA", name: "Alice" })
            compare(resolver.map["0xAAA"], "Alice")

            resolver.enabled = false
            mapSpy.clear()
            usersModel.setProperty(0, "name", "Alicia")
            compare(mapSpy.count, 0)
            compare(resolver.map["0xAAA"], "Alice")   // frozen at the last value
        }

        // Re-enabling rebuilds once when the model changed while disabled.
        function test_reEnableRebuildsWhenOutdated() {
            usersModel.append({ pubKey: "0xAAA", name: "Alice" })
            compare(resolver.map["0xAAA"], "Alice")

            resolver.enabled = false
            usersModel.setProperty(0, "name", "Alicia")
            mapSpy.clear()
            resolver.enabled = true
            verify(mapSpy.count > 0)
            compare(resolver.map["0xAAA"], "Alicia")
        }

        // Re-enabling is a no-op when nothing changed while disabled.
        function test_reEnableNoopWhenUpToDate() {
            usersModel.append({ pubKey: "0xAAA", name: "Alice" })
            compare(resolver.map["0xAAA"], "Alice")

            resolver.enabled = false
            mapSpy.clear()
            resolver.enabled = true
            compare(mapSpy.count, 0)
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
