import QtQuick
import QtTest

import SortFilterProxyModel
import StatusQ

Item {
    id: root

    Component {
        id: testComponent

        QtObject {
            readonly property ListModel source: ListModel {
                Component.onCompleted: {
                    for (let row = 0; row < 200; ++row)
                        append({ color: "blue", type: row % 2, unread: row % 3 })
                }
            }

            readonly property SortFilterProxyModel model: SortFilterProxyModel {
                sourceModel: source
                proxyRoles: [
                    FastExpressionRole {
                        name: "displayColor"
                        expectedRoles: ["color"]
                        expression: model.color
                    },
                    FastExpressionRole {
                        name: "icon"
                        expectedRoles: ["type"]
                        expression: model.type === 0 ? "chat" : "group"
                    },
                    FastExpressionRole {
                        name: "hasNotification"
                        expectedRoles: ["unread"]
                        expression: model.unread > 0
                    }
                ]
            }
        }
    }

    TestCase {
        name: "FastExpressionRoleBenchmark"

        property var testObject

        function init() {
            testObject = createTemporaryObject(testComponent, root)
            verify(!!testObject, "Component exists")
            compare(testObject.model.count, 200)
        }

        function benchmark_roleReads() {
            const model = testObject.model
            let notifications = 0
            let textLength = 0
            for (let read = 0; read < 4700; ++read) {
                const row = read % 200
                textLength += model.get(row, "displayColor").length
                textLength += model.get(row, "icon").length
                notifications += model.get(row, "hasNotification") ? 1 : 0
            }
            compare(textLength, 39950)
            compare(notifications, 3125)
        }
    }
}
