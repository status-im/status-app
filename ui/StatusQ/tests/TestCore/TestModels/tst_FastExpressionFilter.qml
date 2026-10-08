import QtQml
import QtQuick
import QtTest

import SortFilterProxyModel

import StatusQ
import StatusQ.TestHelpers

Item {
    id: root

    Component {
        id: testComponent

        QtObject {
            property int d: 0

            property alias filterEnabled: filter.enabled
            readonly property FastExpressionFilter filterObject: filter

            readonly property FastExpressionFilter replacementFilter: FastExpressionFilter {
                expression: (model.b ?? 0) < 15 && index === model.index && index % 2 === 0
            }

            readonly property ListModel source: ListModel {
                id: listModel

                ListElement { a: 1; b: 11; c: 101 }
                ListElement { a: 2; b: 12; c: 102 }
                ListElement { a: 3; b: 13; c: 103 }
                ListElement { a: 4; b: 14; c: 104 }
                ListElement { a: 5; b: 15; c: 105 }
                ListElement { a: 6; b: 16; c: 106 }
                ListElement { a: 7; b: 17; c: 107 }
            }

            readonly property ListModel alternateSource: ListModel {
                ListElement { unused: 0; c: 30; b: 20; a: 3 }
                ListElement { unused: 1; c: 31; b: 21; a: 1 }
                ListElement { unused: 2; c: 32; b: 22; a: 9 }
            }

            readonly property ModelAccessObserverProxy observer: ModelAccessObserverProxy {
                id: observerProxy

                property int accessCounter: 0

                sourceModel: listModel

                onDataAccessed: accessCounter++
            }

            readonly property SortFilterProxyModel model: SortFilterProxyModel {
                id: testModel

                sourceModel: observerProxy

                filters: FastExpressionFilter {
                    id: filter

                    expression: a > d && a < 5
                    expectedRoles: ["a"]
                }
            }

            readonly property SignalSpy rowsRemovedSpy: SignalSpy {
                target: testModel
                signalName: "rowsRemoved"
            }
        }
    }

    TestCase {
        name: "FastExpressionFilter"

        function test_basicFiltering() {
            const obj = createTemporaryObject(testComponent, root)

            compare(obj.model.count, 4)
            compare(obj.observer.accessCounter, 7)
        }

        function test_filteringAfterContextChange() {
            const obj = createTemporaryObject(testComponent, root)

            compare(obj.rowsRemovedSpy.count, 0)
            obj.d = 1
            compare(obj.rowsRemovedSpy.count, 1)

            compare(obj.observer.accessCounter, 14)
        }

        function test_enabled() {
            const obj = createTemporaryObject(testComponent, root,
                                              { filterEnabled: false })

            compare(obj.model.count, 7)
            compare(obj.observer.accessCounter, 0)

            obj.filterEnabled = true

            compare(obj.model.count, 4)
            compare(obj.observer.accessCounter, 7)
        }

        function test_repeatedContextChanges() {
            const obj = createTemporaryObject(testComponent, root)
            verify(!!obj, "Component exists")

            compare(obj.model.count, 4)
            obj.observer.accessCounter = 0
            obj.d = 1
            compare(obj.model.count, 3)
            obj.d = 2
            compare(obj.model.count, 2)
            obj.d = 0
            compare(obj.model.count, 4)
            compare(obj.observer.accessCounter, 21)
        }

        function test_changingExpressionAndExpectedRoles() {
            const obj = createTemporaryObject(testComponent, root)
            verify(!!obj, "Component exists")

            obj.filterObject.expression = obj.replacementFilter.expression
            compare(obj.model.count, 4)

            obj.filterObject.expectedRoles = ["b"]
            compare(obj.model.count, 2)
            compare(obj.model.get(0, "b"), 11)
            compare(obj.model.get(1, "b"), 13)

            obj.filterObject.expectedRoles = []
            compare(obj.model.count, 4)
            obj.filterObject.expectedRoles = ["b"]
            compare(obj.model.count, 2)
        }

        function test_replacingSource() {
            const obj = createTemporaryObject(testComponent, root)
            verify(!!obj, "Component exists")

            obj.model.sourceModel = obj.alternateSource
            compare(obj.model.count, 2)
            compare(obj.model.get(0, "a"), 3)
            compare(obj.model.get(1, "a"), 1)

            obj.d = 1
            compare(obj.model.count, 1)
            compare(obj.model.get(0, "a"), 3)

            obj.model.sourceModel = obj.observer
            compare(obj.model.count, 3)
            compare(obj.model.get(0, "a"), 2)
        }

        function test_sourceChangesAndInversion() {
            const obj = createTemporaryObject(testComponent, root)
            verify(!!obj, "Component exists")

            obj.source.setProperty(0, "a", 9)
            compare(obj.model.count, 3)
            obj.filterObject.inverted = true
            compare(obj.model.count, 4)
            compare(obj.model.get(0, "a"), 9)

            obj.source.clear()
            compare(obj.model.count, 0)
            obj.source.append({ a: 3, b: 13, c: 103 })
            compare(obj.model.count, 0)
            obj.filterObject.inverted = false
            compare(obj.model.count, 1)
            compare(obj.model.get(0, "a"), 3)
        }
    }
}
