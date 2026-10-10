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
            property int d: 1

            property alias sorterEnabled: sorter.enabled
            property alias sortingAscending: sorter.ascendingOrder
            property alias sorters: testModel.sorters
            readonly property FastExpressionSorter sorterObject: sorter

            readonly property FastExpressionSorter replacementSorter: FastExpressionSorter {
                expression: (modelLeft.b ?? 0) - (modelRight.b ?? 0)
            }

            readonly property FastExpressionSorter indexSorter: FastExpressionSorter {
                expression: modelRight.index - modelLeft.index
            }

            readonly property ListModel source: ListModel {
                id: listModel

                ListElement { a: 1; b: 11; c: 100 }
                ListElement { a: 2; b: 11; c: 101 }
                ListElement { a: 3; b: 13; c: 103 }
                ListElement { a: 4; b: 14; c: 104 }
                ListElement { a: 5; b: 15; c: 105 }
                ListElement { a: 6; b: 16; c: 106 }
                ListElement { a: 2; b: 12; c: 101 }
                ListElement { a: 7; b: 17; c: 107 }
                ListElement { a: 7; b: 17; c: 108 }
            }

            readonly property ListModel alternateSource: ListModel {
                ListElement { unused: 0; c: 30; b: 20; a: 3 }
                ListElement { unused: 1; c: 31; b: 21; a: 1 }
                ListElement { unused: 2; c: 32; b: 22; a: 9 }
            }

            readonly property ModelAccessObserverProxy observer: ModelAccessObserverProxy {
                id: observerProxy

                property int accessCounter: 0
                readonly property var accessedRoles: new Set()

                sourceModel: listModel

                onDataAccessed: {
                    accessCounter++
                    accessedRoles.add(role)
                }
            }

            property SortFilterProxyModel model: SortFilterProxyModel {
                id: testModel

                sourceModel: observerProxy

                sorters: [sorter]
            }

            readonly property Component modelWithPriorityComponent: Component {
                SortFilterProxyModel {
                    id: testModelWithPriority

                    sourceModel: observerProxy

                    sorters: [sorter, otherSorter, roleSorter]
                }
            }

            readonly property FastExpressionSorter sorter: FastExpressionSorter {
                id: sorter

                expression: {
                    // Capture the external dependency even when the rows compare equal.
                    const ascending = d
                    if (modelLeft.a < modelRight.a) 
                        return ascending ? -1 : 1
                    else if (modelLeft.a > modelRight.a)
                        return ascending ? 1 : -1
                    else
                        return 0
                }

                expectedRoles: ["a"]
            }
            
            readonly property FastExpressionSorter otherSorter: FastExpressionSorter {
                id: otherSorter

                expression: {
                    if (modelLeft.b > modelRight.b)
                        return -1
                    else if (modelLeft.b < modelRight.b)
                        return 1
                    else
                        return 0
                }

                expectedRoles: ["b"]
            }

            readonly property RoleSorter roleSorter: RoleSorter {
                id: roleSorter

                roleName: "c"
                ascendingOrder: false
            }

            readonly property SignalSpy rowsRemovedSpy: SignalSpy {
                target: testModel
                signalName: "rowsRemoved"
            }

            readonly property SignalSpy layoutChangedSpy: SignalSpy {
                id: layoutChangedSpy
                target: testModel
                signalName: "layoutChanged"
            }

            readonly property SignalSpy sorterInvalidatedSpy: SignalSpy {
                target: sorter
                signalName: "invalidated"
            }
        }
    }

    Component {
        id: boolSorterComponent

        QtObject {
            property bool byB: false
            property alias ascending: boolSorter.ascendingOrder

            readonly property ListModel source: ListModel {
                ListElement { a: 3; b: 1; c: 0 }
                ListElement { a: 1; b: 3; c: 1 }
                ListElement { a: 2; b: 2; c: 2 }
                ListElement { a: 1; b: 4; c: 3 }
                ListElement { a: 3; b: 0; c: 4 }
            }

            readonly property SortFilterProxyModel model: SortFilterProxyModel {
                sourceModel: source
                sorters: FastExpressionSorter {
                    id: boolSorter
                    expectedRoles: ["a", "b"]
                    expression: byB ? modelLeft.b < modelRight.b
                                    : modelLeft.a < modelRight.a
                }
            }

            function column(role) {
                const values = []
                for (let i = 0; i < model.count; ++i)
                    values.push(model.get(i, role))
                return values
            }
        }
    }

    Component {
        id: millisecondTimestampSortingComponent

        QtObject {
            readonly property ListModel source: ListModel {
                ListElement { timestamp: 1577836800000 }
                ListElement { timestamp: 1767225600000 }
                ListElement { timestamp: 1704067200000 }
            }

            readonly property SortFilterProxyModel model: SortFilterProxyModel {
                sourceModel: source
                sorters: FastExpressionSorter {
                    expectedRoles: ["timestamp"]
                    expression: {
                        if (modelLeft.timestamp > modelRight.timestamp)
                            return -1
                        if (modelLeft.timestamp < modelRight.timestamp)
                            return 1
                        return 0
                    }
                }
            }
        }
    }

    TestCase {
        name: "FastExpressionSorter"

        function test_basicSorting() {
            const obj = createTemporaryObject(testComponent, root)
            const count = obj.model.count

            compare(count, 9)
            verify(obj.observer.accessCounter
                   < count * Math.ceil(Math.log2(count)) * 3)
            compare(obj.observer.accessedRoles.size, 1)

            compare(obj.model.get(0).a, 1)
            compare(obj.model.get(1).a, 2)
            compare(obj.model.get(7).a, 7)
        }

        function test_millisecondTimestampSorting() {
            const obj = createTemporaryObject(millisecondTimestampSortingComponent, root)

            compare(obj.model.get(0).timestamp, 1767225600000)
            compare(obj.model.get(1).timestamp, 1704067200000)
            compare(obj.model.get(2).timestamp, 1577836800000)
        }

        function test_sortingAfterContextChange() {
            const obj = createTemporaryObject(testComponent, root)
            const count = obj.model.count

            obj.observer.accessCounter = 0

            obj.d = 0

            verify(obj.observer.accessCounter
                   < count * Math.ceil(Math.log2(count)) * 3)
            compare(obj.observer.accessedRoles.size, 1)

            tryVerify(() => obj.model.get(0, "a") === 7)
            tryVerify(() => obj.model.get(1, "a") === 7)
            tryVerify(() => obj.model.get(8, "a") === 1)
        }

        function test_enabled() {
            const obj = createTemporaryObject(testComponent, root,
                                              { sorterEnabled: false, d: 0 })
            compare(obj.observer.accessCounter, 0)

            compare(obj.model.get(0).a, 1)
            compare(obj.model.get(1).a, 2)
            compare(obj.model.get(7).a, 7)

            obj.observer.accessedRoles.clear()
            obj.observer.accessCounter = 0
            obj.sorterEnabled = true

            const count = obj.model.count

            verify(obj.observer.accessCounter
                   < count * Math.ceil(Math.log2(count)) * 3)
            compare(obj.observer.accessedRoles.size, 1)

            compare(obj.model.get(0).a, 7)
            compare(obj.model.get(1).a, 7)
            compare(obj.model.get(7).a, 2)
            compare(obj.model.get(8).a, 1)
        }

        function test_sortingDescending() {
            const obj = createTemporaryObject(testComponent, root)

            const count = obj.model.count

            verify(obj.observer.accessCounter
                   < count * Math.ceil(Math.log2(count)) * 3)
            compare(obj.observer.accessedRoles.size, 1)


            compare(obj.model.get(0).a, 1)
            compare(obj.model.get(1).a, 2)
            compare(obj.model.get(7).a, 7)

            obj.observer.accessCounter = 0

            obj.sortingAscending = false

            tryVerify(() => obj.observer.accessCounter
                   < count * Math.ceil(Math.log2(count)) * 3)

            tryVerify(() => obj.model.get(0, "a") === 7)
            tryVerify(() => obj.model.get(1, "a") === 7)
            tryVerify(() => obj.model.get(8, "a") === 1)
        }

        function test_sortingDescendingAfterEnablingSorting() {
            const obj = createTemporaryObject(testComponent, root, { sorterEnabled: false, sortingAscending: false })

            compare(obj.observer.accessCounter, 0)
            compare(obj.observer.accessedRoles.size, 0)

            compare(obj.model.get(0).a, 1)
            compare(obj.model.get(1).a, 2)
            compare(obj.model.get(7).a, 7)

            obj.observer.accessedRoles.clear()
            obj.observer.accessCounter = 0

            obj.sorterEnabled = true

            const count = obj.model.count

            verify(obj.observer.accessCounter
                   < count * Math.ceil(Math.log2(count)) * 3)

            compare(obj.observer.accessedRoles.size, 1)

            compare(obj.model.get(0).a, 7)
            compare(obj.model.get(1).a, 7)
            compare(obj.model.get(8).a, 1)

            obj.observer.accessedRoles.clear()
            obj.observer.accessCounter = 0

            obj.sorterEnabled = false

            verify(obj.observer.accessCounter == 0)

            compare(obj.observer.accessedRoles.size, 0)

            compare(obj.model.get(0).a, 1)
            compare(obj.model.get(1).a, 2)
            compare(obj.model.get(7).a, 7)
        }

        function test_stableSorting() {
            const obj = createTemporaryObject(testComponent, root)

            compare(obj.model.get(0).a, 1)
            compare(obj.model.get(1).a, 2)
            compare(obj.model.get(2).a, 2)
            compare(obj.model.get(0).b, 11)
            compare(obj.model.get(1).b, 11)
            compare(obj.model.get(2).b, 12)
            compare(obj.model.get(0).c, 100)
            compare(obj.model.get(1).c, 101)
            compare(obj.model.get(2).c, 101)

            obj.sortingAscending = false

            compare(obj.model.get(8).a, 1)
            compare(obj.model.get(7).a, 2)
            compare(obj.model.get(6).a, 2)
            compare(obj.model.get(8).b, 11)
            compare(obj.model.get(7).b, 12)
            compare(obj.model.get(6).b, 11)
            compare(obj.model.get(8).c, 100)
            compare(obj.model.get(7).c, 101)
            compare(obj.model.get(6).c, 101)


            obj.sortingAscending = true

            compare(obj.model.get(0).a, 1)
            compare(obj.model.get(1).a, 2)
            compare(obj.model.get(2).a, 2)
            compare(obj.model.get(0).b, 11)
            compare(obj.model.get(1).b, 11)
            compare(obj.model.get(2).b, 12)
            compare(obj.model.get(0).c, 100)
            compare(obj.model.get(1).c, 101)
            compare(obj.model.get(2).c, 101)

            obj.source.append({a: 2, b: 13, c: 101})

            compare(obj.model.get(0).a, 1)
            compare(obj.model.get(1).a, 2)
            compare(obj.model.get(2).a, 2)
            compare(obj.model.get(3).a, 2)
            compare(obj.model.get(0).b, 11)
            compare(obj.model.get(1).b, 11)
            compare(obj.model.get(2).b, 12)
            compare(obj.model.get(3).b, 13)
            compare(obj.model.get(0).c, 100)
            compare(obj.model.get(1).c, 101)
            compare(obj.model.get(2).c, 101)
            compare(obj.model.get(3).c, 101)

            obj.sortingAscending = false

            compare(obj.model.get(9).a, 1)
            compare(obj.model.get(8).a, 2)
            compare(obj.model.get(7).a, 2)
            compare(obj.model.get(6).a, 2)
            compare(obj.model.get(9).b, 11)
            compare(obj.model.get(8).b, 13)
            compare(obj.model.get(7).b, 12)
            compare(obj.model.get(6).b, 11)
            compare(obj.model.get(9).c, 100)
            compare(obj.model.get(8).c, 101)
            compare(obj.model.get(7).c, 101)
            compare(obj.model.get(6).c, 101)
        }

        function test_default_stableSorting() {
            const obj = createTemporaryObject(testComponent, root, { sorters: [] })

            obj.model.sortRoleName = "a"
            obj.model.ascendingSortOrder = true

            compare(obj.model.get(0).a, 1)
            compare(obj.model.get(1).a, 2)
            compare(obj.model.get(2).a, 2)
            compare(obj.model.get(0).b, 11)
            compare(obj.model.get(1).b, 11)
            compare(obj.model.get(2).b, 12)
            compare(obj.model.get(0).c, 100)
            compare(obj.model.get(1).c, 101)
            compare(obj.model.get(2).c, 101)

            obj.model.ascendingSortOrder = false

            compare(obj.model.get(8).a, 1)
            compare(obj.model.get(7).a, 2)
            compare(obj.model.get(6).a, 2)
            compare(obj.model.get(8).b, 11)
            compare(obj.model.get(7).b, 12)
            compare(obj.model.get(6).b, 11)
            compare(obj.model.get(8).c, 100)
            compare(obj.model.get(7).c, 101)
            compare(obj.model.get(6).c, 101)


            obj.model.ascendingSortOrder = true

            compare(obj.model.get(0).a, 1)
            compare(obj.model.get(1).a, 2)
            compare(obj.model.get(2).a, 2)
            compare(obj.model.get(0).b, 11)
            compare(obj.model.get(1).b, 11)
            compare(obj.model.get(2).b, 12)
            compare(obj.model.get(0).c, 100)
            compare(obj.model.get(1).c, 101)
            compare(obj.model.get(2).c, 101)

            obj.source.append({a: 2, b: 13, c: 101})

            compare(obj.model.get(0).a, 1)
            compare(obj.model.get(1).a, 2)
            compare(obj.model.get(2).a, 2)
            compare(obj.model.get(3).a, 2)
            compare(obj.model.get(0).b, 11)
            compare(obj.model.get(1).b, 11)
            compare(obj.model.get(2).b, 12)
            compare(obj.model.get(3).b, 13)
            compare(obj.model.get(0).c, 100)
            compare(obj.model.get(1).c, 101)
            compare(obj.model.get(2).c, 101)
            compare(obj.model.get(3).c, 101)

            obj.model.ascendingSortOrder = false

            compare(obj.model.get(9).a, 1)
            compare(obj.model.get(8).a, 2)
            compare(obj.model.get(7).a, 2)
            compare(obj.model.get(6).a, 2)
            compare(obj.model.get(9).b, 11)
            compare(obj.model.get(8).b, 13)
            compare(obj.model.get(7).b, 12)
            compare(obj.model.get(6).b, 11)
            compare(obj.model.get(9).c, 100)
            compare(obj.model.get(8).c, 101)
            compare(obj.model.get(7).c, 101)
            compare(obj.model.get(6).c, 101)
        }

        function test_sortWithPriority() {
            const obj = createTemporaryObject(testComponent, root)

            obj.model = createTemporaryObject(obj.modelWithPriorityComponent, obj)

            compare(obj.model.get(0).a, 1)
            compare(obj.model.get(1).a, 2)
            compare(obj.model.get(2).a, 2)
            compare(obj.model.get(0).b, 11)
            compare(obj.model.get(1).b, 12) // descending "b"
            compare(obj.model.get(2).b, 11)
            compare(obj.model.get(0).c, 100)
            compare(obj.model.get(1).c, 101)
            compare(obj.model.get(2).c, 101)
            compare(obj.model.get(7).a, 7)
            compare(obj.model.get(8).a, 7)
            compare(obj.model.get(7).c, 108) // descending "c"
            compare(obj.model.get(8).c, 107)
        }

        function test_repeatedContextChanges() {
            const obj = createTemporaryObject(testComponent, root)
            verify(!!obj, "Component exists")

            compare(obj.model.get(0, "a"), 1)
            wait(0)
            obj.sorterInvalidatedSpy.clear()
            wait(0)
            compare(obj.sorterInvalidatedSpy.count, 0)

            obj.d = 0
            tryVerify(() => obj.model.get(0, "a") === 7)
            tryCompare(obj.sorterInvalidatedSpy, "count", 1)
            obj.d = 1
            tryVerify(() => obj.model.get(0, "a") === 1)
            tryCompare(obj.sorterInvalidatedSpy, "count", 2)
            obj.d = 0
            tryVerify(() => obj.model.get(0, "a") === 7)
            tryCompare(obj.sorterInvalidatedSpy, "count", 3)
        }

        function test_changingExpressionAndExpectedRoles() {
            const obj = createTemporaryObject(testComponent, root)
            verify(!!obj, "Component exists")

            obj.sorterObject.expression = obj.replacementSorter.expression
            obj.sorterObject.expectedRoles = ["b"]
            tryVerify(() => obj.model.get(2, "b") === 12)

            obj.sorterObject.expectedRoles = []
            tryVerify(() => obj.model.get(2, "b") === 13)
            obj.sorterObject.expectedRoles = ["b"]
            tryVerify(() => obj.model.get(2, "b") === 12)
        }

        function test_replacingSource() {
            const obj = createTemporaryObject(testComponent, root)
            verify(!!obj, "Component exists")

            obj.model.sourceModel = obj.alternateSource
            compare(obj.model.count, 3)
            compare(obj.model.get(0, "a"), 1)
            compare(obj.model.get(1, "a"), 3)
            compare(obj.model.get(2, "a"), 9)

            obj.d = 0
            tryVerify(() => obj.model.get(0, "a") === 9)

            obj.model.sourceModel = obj.observer
            compare(obj.model.count, 9)
            compare(obj.model.get(0, "a"), 7)
            compare(obj.model.get(8, "a"), 1)
        }

        function test_sourceRowIndex() {
            const obj = createTemporaryObject(testComponent, root)
            verify(!!obj, "Component exists")

            obj.sorterObject.expression = obj.indexSorter.expression
            obj.sorterObject.expectedRoles = []
            tryVerify(() => obj.model.get(0, "c") === 108)
            compare(obj.model.get(8, "c"), 100)

            obj.source.clear()
            compare(obj.model.count, 0)
            obj.source.append({ a: 4, b: 14, c: 104 })
            obj.source.append({ a: 1, b: 11, c: 101 })
            compare(obj.model.get(0, "c"), 101)
            compare(obj.model.get(1, "c"), 104)
        }

        function test_booleanExpression() {
            const obj = createTemporaryObject(boolSorterComponent, root)
            verify(!!obj, "Component exists")

            // Equal values keep the source order (stable sort).
            compare(obj.column("a"), [1, 1, 2, 3, 3])
            compare(obj.column("c"), [1, 3, 2, 0, 4])

            obj.ascending = false
            compare(obj.column("a"), [3, 3, 2, 1, 1])
            compare(obj.column("c"), [0, 4, 2, 1, 3])

            obj.ascending = true
            obj.byB = true
            tryVerify(() => obj.model.get(0, "b") === 0)
            compare(obj.column("b"), [0, 1, 2, 3, 4])
        }
    }
}
