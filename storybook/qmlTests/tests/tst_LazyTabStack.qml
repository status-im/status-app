import QtQuick
import QtTest

import shared.controls

Item {
    id: root
    width: 400
    height: 300

    QtObject {
        id: d
        property int createdA: 0
        property int createdB: 0
        property int createdC: 0
    }

    Component {
        id: tabA
        Item { Component.onCompleted: d.createdA++ }
    }
    Component {
        id: tabB
        Item { Component.onCompleted: d.createdB++ }
    }
    Component {
        id: tabC
        Item { Component.onCompleted: d.createdC++ }
    }

    Component {
        id: componentUnderTest
        LazyTabStack {
            anchors.fill: parent
            asynchronous: false
            tabComponents: [tabA, tabB, tabC]
        }
    }

    Component {
        id: asyncComponentUnderTest
        LazyTabStack {
            anchors.fill: parent
            asynchronous: true
            tabComponents: [tabA, tabB, tabC]
        }
    }

    TestCase {
        name: "LazyTabStack"
        when: windowShown

        property LazyTabStack controlUnderTest: null

        function init() {
            d.createdA = 0
            d.createdB = 0
            d.createdC = 0
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
        }

        function test_createsOnlyTheCurrentTab() {
            verify(!!controlUnderTest)
            compare(controlUnderTest.currentIndex, 0)
            compare(d.createdA, 1)
            compare(d.createdB, 0)
            compare(d.createdC, 0)
            verify(controlUnderTest.currentReady)
            verify(!!controlUnderTest.itemAt(0))
            compare(controlUnderTest.itemAt(1), null)
        }

        function test_keepsAViewAliveAcrossSwitches() {
            controlUnderTest.currentIndex = 1
            compare(d.createdB, 1)
            const tabBItem = controlUnderTest.itemAt(1)
            verify(!!tabBItem)

            controlUnderTest.currentIndex = 0
            controlUnderTest.currentIndex = 1

            compare(d.createdA, 1)
            compare(d.createdB, 1)
            compare(d.createdC, 0)
            compare(controlUnderTest.itemAt(1), tabBItem)
            verify(!!controlUnderTest.itemAt(0))
        }

        function test_showsOnlyTheCurrentTab() {
            controlUnderTest.currentIndex = 2
            verify(controlUnderTest.currentReady)
            verify(!controlUnderTest.itemAt(0).parent.visible)
            verify(controlUnderTest.itemAt(2).parent.visible)

            controlUnderTest.currentIndex = 0
            verify(controlUnderTest.itemAt(0).parent.visible)
            verify(!controlUnderTest.itemAt(2).parent.visible)
        }

        function test_reportsReadinessWhileLoadingAsynchronously() {
            d.createdA = 0
            d.createdB = 0
            const control = createTemporaryObject(asyncComponentUnderTest, root)
            verify(!!control)
            verify(!control.currentReady)
            tryVerify(() => control.currentReady)
            compare(d.createdA, 1)

            control.currentIndex = 1
            verify(!control.currentReady)
            tryVerify(() => control.currentReady)
            compare(d.createdB, 1)

            control.currentIndex = 0
            verify(control.currentReady)
        }
    }
}
