import QtQml
import QtQuick
import QtTest

import SortFilterProxyModel

import StatusQ
import StatusQ.Core.Utils

import StatusQ.TestHelpers

Item {
    id: root

    Component {
        id: testComponent

        QtObject {
            property int d: 0

            readonly property FastExpressionRole replacementRole: FastExpressionRole {
                expression: a * model.b + d + model.index
            }

            readonly property ListModel source: ListModel {
                id: listModel

                ListElement { a: 1; b: 2; c: 3 }
            }

            readonly property ListModel alternateSource: ListModel {
                ListElement { unused: 123; c: 30; b: 20; a: 10 }
            }

            readonly property ModelAccessObserverProxy observer: ModelAccessObserverProxy {
                id: observerProxy

                property int accessCounter: 0

                sourceModel: listModel

                onDataAccessed: accessCounter++
            }

            readonly property FastExpressionRole expressionRole: expressionRole

            readonly property SortFilterProxyModel model: SortFilterProxyModel {
                id: testModel

                sourceModel: observerProxy

                proxyRoles: [
                    FastExpressionRole {
                        id: expressionRole

                        name: "expressionRole"
                        expression: a + model.b + (model.c ?? 0) + d + index

                        expectedRoles: ["a", "b"]
                    },
                    FastExpressionRole {
                        name: "expressionRole2"
                        expression: "staticRole"
                    },
                    FastExpressionRole {
                        name: "derivedRole"
                        expectedRoles: ["expressionRole"]
                        expression: model.expressionRole * 2
                    }
                ]
            }

            readonly property Instantiator instantiator: Instantiator {
                model: testModel

                QtObject {
                    property string expressionRole: model.expressionRole
                }
            }

            readonly property SignalSpy modelSignalSpy: SignalSpy {
                target: testModel
                signalName: "dataChanged"
            }
        }
    }

    TestCase {
        name: "FastExpressionRole"

        function test_expressionRoleValue() {
            const obj = createTemporaryObject(testComponent, root)

            const instantiator = obj.instantiator
            const listModel = obj.source

            fuzzyCompare(instantiator.object.expressionRole, 3, 1e-7)
            listModel.setProperty(0, "b", 9)
            fuzzyCompare(instantiator.object.expressionRole, 10, 1e-7)
            obj.d = 42
            fuzzyCompare(instantiator.object.expressionRole, 52, 1e-7)
        }

        function test_expressionRoleAccessToSource() {
            const obj = createTemporaryObject(testComponent, root)

            const testModel = obj.model
            const observerProxy = obj.observer

            observerProxy.accessCounter = 0

            ModelUtils.get(testModel, 0, "expressionRole")
            compare(observerProxy.accessCounter, 2)

            ModelUtils.get(testModel, 0, "expressionRole2")
            compare(observerProxy.accessCounter, 2)
        }

        function test_expressionRoleAccessToSourceViaContextChange() {
            const obj = createTemporaryObject(testComponent, root)

            const testModel = obj.model
            const observerProxy = obj.observer

            const instantiator = obj.instantiator

            observerProxy.accessCounter = 0
            compare(obj.modelSignalSpy.count, 0)

            obj.d = 1

            compare(obj.modelSignalSpy.count, 1)
            compare(observerProxy.accessCounter, 4)
        }

        function test_expressionRoleChangeExpectedRoles() {
            const obj = createTemporaryObject(testComponent, root)

            const instantiator = obj.instantiator
            const expressionRole = obj.expressionRole

            fuzzyCompare(instantiator.object.expressionRole, 3, 1e-7)

            expressionRole.expectedRoles = ["a", "b", "c"]
            fuzzyCompare(instantiator.object.expressionRole, 6, 1e-7)

            expressionRole.expectedRoles = ["a", "b"]
            fuzzyCompare(instantiator.object.expressionRole, 3, 1e-7)
        }

        function test_expressionRoleAlternatingRows() {
            const obj = createTemporaryObject(testComponent, root)
            verify(!!obj, "Component exists")

            obj.source.append({ a: 10, b: 20, c: 30 })
            obj.modelSignalSpy.clear()
            obj.observer.accessCounter = 0

            for (let read = 0; read < 10; ++read) {
                compare(obj.model.get(0, "expressionRole"), 3)
                compare(obj.model.get(1, "expressionRole"), 31)
            }
            compare(obj.observer.accessCounter, 40)
            compare(obj.modelSignalSpy.count, 0)

            obj.d = 2
            compare(obj.model.get(0, "expressionRole"), 5)
            compare(obj.model.get(1, "expressionRole"), 33)
            compare(obj.modelSignalSpy.count, 1)
        }

        function test_expressionRoleChangingExpression() {
            const obj = createTemporaryObject(testComponent, root)
            verify(!!obj, "Component exists")

            obj.source.append({ a: 10, b: 20, c: 30 })
            obj.expressionRole.expression = obj.replacementRole.expression
            compare(obj.model.get(0, "expressionRole"), 2)
            compare(obj.model.get(1, "expressionRole"), 201)

            obj.d = 4
            compare(obj.model.get(0, "expressionRole"), 6)
            compare(obj.model.get(1, "expressionRole"), 205)
        }

        function test_expressionRoleReplacingSource() {
            const obj = createTemporaryObject(testComponent, root)
            const replacement = createTemporaryObject(testComponent, root)
            verify(!!obj, "Component exists")
            verify(!!replacement, "Component exists")

            compare(obj.model.get(0, "expressionRole"), 3)
            obj.model.sourceModel = replacement.source
            replacement.source.setProperty(0, "a", 9)
            compare(obj.model.get(0, "expressionRole"), 11)

            replacement.source.clear()
            replacement.source.append({ a: 4, b: 5, c: 6 })
            compare(obj.model.get(0, "expressionRole"), 9)

            obj.model.sourceModel = obj.alternateSource
            compare(obj.model.get(0, "expressionRole"), 30)
            obj.expressionRole.expectedRoles = ["a", "b", "c"]
            compare(obj.model.get(0, "expressionRole"), 60)

            obj.model.sourceModel = obj.source
            compare(obj.model.get(0, "expressionRole"), 6)
        }

        function test_expressionRoleDependingOnProxyRole() {
            const obj = createTemporaryObject(testComponent, root)
            verify(!!obj, "Component exists")

            obj.source.append({ a: 10, b: 20, c: 30 })
            compare(obj.model.get(0, "derivedRole"), 6)
            compare(obj.model.get(1, "derivedRole"), 62)

            obj.d = 2
            compare(obj.model.get(0, "derivedRole"), 10)
            compare(obj.model.get(1, "derivedRole"), 66)

            obj.source.setProperty(0, "a", 4)
            compare(obj.model.get(0, "derivedRole"), 16)
            compare(obj.model.get(1, "derivedRole"), 66)
        }

        function test_expressionRoleSourceRowIndex() {
            const obj = createTemporaryObject(testComponent, root)
            verify(!!obj, "Component exists")

            obj.source.append({ a: 10, b: 20, c: 30 })
            compare(obj.model.get(1, "expressionRole"), 31)

            obj.source.insert(0, { a: 4, b: 5, c: 6 })
            compare(obj.model.get(0, "expressionRole"), 9)
            compare(obj.model.get(1, "expressionRole"), 4)
            compare(obj.model.get(2, "expressionRole"), 32)

            obj.source.move(2, 0, 1)
            compare(obj.model.get(0, "expressionRole"), 30)
            compare(obj.model.get(1, "expressionRole"), 10)
            compare(obj.model.get(2, "expressionRole"), 5)

            obj.source.remove(0)
            compare(obj.model.get(0, "expressionRole"), 9)
            compare(obj.model.get(1, "expressionRole"), 4)
        }
    }
}
