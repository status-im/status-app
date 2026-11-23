import QtQuick
import QtTest

import StatusQ.Core.Utils

TestCase {
    id: testCase
    name: "DeferredLoader"

    Component {
        id: loaderComponent

        DeferredLoader {
            url: Qt.resolvedUrl("DeferredLoaderFixture.qml")
        }
    }

    Component {
        id: counterComponent

        QtObject {
            property int count
            property int value: 7
        }
    }

    function createLoader(counter, active, extraProps = {}) {
        const loader = createTemporaryObject(loaderComponent, testCase, {
            active: active,
            properties: Object.assign({ value: 7, counter: counter }, extraProps)
        })
        verify(!!loader)
        return loader
    }

    function test_inactive_creates_nothing() {
        const counter = createTemporaryObject(counterComponent, testCase)
        const loader = createLoader(counter, false)
        compare(loader.item, null)
        compare(counter.count, 0)
    }

    function test_active_at_creation_creates_once() {
        const counter = createTemporaryObject(counterComponent, testCase)
        const loader = createLoader(counter, true)
        verify(!!loader.item)
        compare(loader.item.value, 7)
        compare(counter.count, 1)
    }

    function test_properties_survive_active_toggles() {
        const counter = createTemporaryObject(counterComponent, testCase)
        const loader = createLoader(counter, false)

        loader.active = true
        compare(loader.item.value, 7)
        compare(counter.count, 1)

        loader.active = false
        compare(loader.item, null)

        loader.active = true
        verify(!!loader.item)
        compare(loader.item.value, 7)
        compare(counter.count, 2)
    }

    function test_binding_property() {
        const counter = createTemporaryObject(counterComponent, testCase)
        const loader = createLoader(counter, true, { value: Qt.binding(() => counter.value) })
        compare(loader.item.value, 7)
        counter.value = 9
        compare(loader.item.value, 9)
        compare(counter.count, 1)
    }
}
