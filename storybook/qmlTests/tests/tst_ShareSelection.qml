import QtQuick
import QtTest

import mainui

Item {
    Component {
        id: selectionComponent
        ShareSelection {}
    }

    Component {
        id: modelComponent
        ListModel {
            ListElement { chatId: "a" }
            ListElement { chatId: "b" }
        }
    }

    SignalSpy { id: changedSpy; signalName: "changed" }

    TestCase {
        name: "ShareSelection"

        function init() { changedSpy.clear() }

        function test_toggleAddsThenRemoves() {
            const sel = createTemporaryObject(selectionComponent, this)
            changedSpy.target = sel
            sel.toggle("a")
            verify(sel.contains("a"))
            compare(sel.count, 1)
            compare(changedSpy.count, 1)
            sel.toggle("a")
            verify(!sel.contains("a"))
            compare(sel.count, 0)
            compare(changedSpy.count, 2)
        }

        function test_toggleRefusesNewIdsWhileFullUntilOneIsRemoved() {
            const sel = createTemporaryObject(selectionComponent, this, { maxCount: 2 })
            changedSpy.target = sel
            sel.toggle("a")
            sel.toggle("b")
            verify(sel.isFull)
            compare(changedSpy.count, 2)

            sel.toggle("c")
            verify(!sel.contains("c"))
            compare(sel.count, 2)
            compare(changedSpy.count, 2)

            sel.toggle("a")   // unticking is always allowed
            verify(!sel.isFull)
            sel.toggle("c")
            verify(sel.contains("c"))
            compare(sel.count, 2)
        }

        function test_clearEmptiesAndNotifies() {
            const sel = createTemporaryObject(selectionComponent, this)
            changedSpy.target = sel
            sel.toggle("a"); sel.toggle("b")
            sel.clear()
            compare(sel.count, 0)
            compare(changedSpy.count, 3)
        }

        function test_retainOnlyDropsIdsMissingFromModel() {
            const sel = createTemporaryObject(selectionComponent, this)
            const model = createTemporaryObject(modelComponent, this)
            sel.toggle("a"); sel.toggle("gone")
            sel.retainOnly(model)
            compare(sel.chatIds, ["a"])
        }

        function test_retainOnlyDoesNotNotifyWhenNothingChanges() {
            const sel = createTemporaryObject(selectionComponent, this)
            const model = createTemporaryObject(modelComponent, this)
            sel.toggle("a")
            changedSpy.target = sel
            changedSpy.clear()
            sel.retainOnly(model)
            compare(changedSpy.count, 0)
        }
    }
}
