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
            property int minimum: 0

            readonly property ListModel source: ListModel {
                Component.onCompleted: {
                    for (let row = 0; row < 200; ++row) {
                        const item = { a: row, b: row % 2 }
                        for (let role = 0; role < extraRoles; ++role)
                            item["unused" + role] = row + role
                        append(item)
                    }
                }
            }

            readonly property SortFilterProxyModel model: SortFilterProxyModel {
                sourceModel: source
                filters: FastExpressionFilter {
                    expectedRoles: ["a", "b"]
                    expression: model.a >= minimum && model.b === 0
                }
            }
        }
    }

    TestCase {
        name: "FastExpressionFilterBenchmark"

        function benchmark_filterRows_data() {
            return [
                { tag: "2 roles", extraRoles: 0 },
                { tag: "42 roles", extraRoles: 40 }
            ]
        }

        function benchmark_filterRows(data) {
            const obj = createTemporaryObject(testComponent, root,
                                              { extraRoles: data.extraRoles })
            verify(!!obj, "Component exists")
            for (let pass = 0; pass < 50; ++pass) {
                obj.minimum = pass % 2
                compare(obj.model.count, 100 - pass % 2)
            }
            compare(obj.model.get(obj.model.count - 1, "a"), 198)
        }
    }
}
