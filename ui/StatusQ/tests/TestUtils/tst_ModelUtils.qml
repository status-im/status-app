import QtQml
import QtQuick
import QtTest

import StatusQ.Core.Utils
import StatusQ.TestHelpers

Item {
    id: root
    width: 200
    height: 200

    Component {
        id: flatComponent

        QtObject {
            readonly property ListModel source: ListModel {
                id: flatModel
                ListElement { key: "k0"; name: "Zero"; extra: "e0" }
                ListElement { key: "k1"; name: "One";  extra: "e1" }
                ListElement { key: "k2"; name: "Two";  extra: "e2" }
            }

            property var accessedRoles: []

            readonly property ModelAccessObserverProxy observer: ModelAccessObserverProxy {
                sourceModel: flatModel
                onDataAccessed: (row, role, value) => accessedRoles.push(role)
            }
        }
    }

    Component {
        id: nestedComponent

        QtObject {
            readonly property ListModel source: ListModel {
                id: nestedModel
                ListElement {
                    key: "k0"
                    sub: [ ListElement { v: 1 }, ListElement { v: 2 } ]
                }
                ListElement {
                    key: "k1"
                    sub: [ ListElement { v: 3 } ]
                }
            }
        }
    }

    TestCase {
        name: "ModelUtils"

        // The join asks for one role; the fix must fetch ONLY that role per row via
        // the single-role ModelQuery.get, not the all-roles get. The observer counts
        // one data() access per row (== rowCount), not one per (row, role): on the
        // old all-roles path this model would report rowCount * 3.
        function test_joinModelEntries_fetches_only_requested_role() {
            const obj = createTemporaryObject(flatComponent, root)

            const joined = ModelUtils.joinModelEntries(obj.observer, "key", "$$")

            compare(joined, "k0$$k1$$k2")
            compare(obj.accessedRoles.length, obj.source.rowCount(),
                    "join over one role must access exactly one role per row")
        }

        // modelToFlatArray / modelToArray with an explicit subset of roles.
        function test_modelToFlatArray_subset() {
            const obj = createTemporaryObject(flatComponent, root)
            const keys = ModelUtils.modelToFlatArray(obj.observer, "key")
            compare(keys, ["k0", "k1", "k2"])
        }

        function test_modelToArray_explicit_two_roles() {
            const obj = createTemporaryObject(flatComponent, root)
            const arr = ModelUtils.modelToArray(obj.source, ["key", "name"])
            compare(arr.length, 3)
            compare(arr[0].key, "k0")
            compare(arr[0].name, "Zero")
            verify(arr[0].extra === undefined, "unrequested role must not be present")
        }

        // With no roles given, every role is returned (the single all-roles get path).
        function test_modelToArray_all_roles_default() {
            const obj = createTemporaryObject(flatComponent, root)
            const arr = ModelUtils.modelToArray(obj.source)
            compare(arr.length, 3)
            compare(arr[1].key, "k1")
            compare(arr[1].name, "One")
            compare(arr[1].extra, "e1")
        }

        // A submodel role fetched via the single-role path must still be detected as a
        // model and recursed into.
        function test_modelToArray_submodel_role_recurses() {
            const obj = createTemporaryObject(nestedComponent, root)
            const arr = ModelUtils.modelToArray(obj.source, ["key", "sub"])
            compare(arr.length, 2)
            compare(arr[0].key, "k0")
            compare(arr[0].sub.length, 2)
            compare(arr[0].sub[0].v, 1)
            compare(arr[0].sub[1].v, 2)
            compare(arr[1].sub.length, 1)
            compare(arr[1].sub[0].v, 3)
        }

        function test_modelToArray_null_model() {
            compare(ModelUtils.modelToArray(null, ["key"]), [])
        }
    }
}
