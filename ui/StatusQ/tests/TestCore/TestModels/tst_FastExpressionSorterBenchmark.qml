import QtQuick
import QtTest

import SortFilterProxyModel
import StatusQ

Item {
    id: root

    Component {
        id: testComponent

        QtObject {
            property int extraRoles: 0
            property alias ascending: sorter.ascendingOrder

            readonly property ListModel source: ListModel {
                Component.onCompleted: {
                    for (let row = 0; row < 200; ++row) {
                        const item = { a: (row * 73) % 200, b: row }
                        for (let role = 0; role < extraRoles; ++role)
                            item["unused" + role] = row + role
                        append(item)
                    }
                }
            }

            readonly property SortFilterProxyModel model: SortFilterProxyModel {
                sourceModel: source
                sorters: FastExpressionSorter {
                    id: sorter
                    expectedRoles: ["a"]
                    expression: modelLeft.a - modelRight.a
                }
            }
        }
    }

    TestCase {
        name: "FastExpressionSorterBenchmark"

        function benchmark_sortRows_data() {
            return [
                { tag: "2 roles", extraRoles: 0 },
                { tag: "42 roles", extraRoles: 40 }
            ]
        }

        function benchmark_sortRows(data) {
            const obj = createTemporaryObject(testComponent, root,
                                              { extraRoles: data.extraRoles })
            verify(!!obj, "Component exists")
            for (let pass = 0; pass < 10; ++pass) {
                obj.ascending = pass % 2 === 0
                compare(obj.model.count, 200)
                compare(obj.model.get(0, "a"), pass % 2 === 0 ? 0 : 199)
                compare(obj.model.get(199, "a"), pass % 2 === 0 ? 199 : 0)
            }
        }
    }
}
