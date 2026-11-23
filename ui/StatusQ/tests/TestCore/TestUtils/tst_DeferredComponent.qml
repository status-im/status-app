import QtQuick
import QtTest

import StatusQ.Core.Utils

TestCase {
    id: testCase
    name: "DeferredComponent"

    Component {
        id: deferredComponent

        DeferredComponent {
            id: deferred

            readonly property SignalSpy createdSpy: SignalSpy {
                target: deferred
                signalName: "created"
            }
        }
    }

    function createDeferred(props) {
        const deferred = createTemporaryObject(deferredComponent, testCase, props)
        verify(!!deferred)
        return deferred
    }

    function test_createObject_data() {
        return [
            { tag: "source", props: { source: Qt.resolvedUrl("DeferredComponentFixture.qml") } },
            { tag: "module", props: { module: "QtQuick", typeName: "Item" } }
        ]
    }

    function test_createObject(data) {
        const deferred = createDeferred(data.props)
        const object = deferred.createObject(testCase)
        verify(!!object)
        compare(deferred.createdSpy.count, 1)
        compare(deferred.createdSpy.signalArguments[0][0], object)
        object.destroy()
    }

    function test_properties_and_overrides() {
        const deferred = createDeferred({
            source: Qt.resolvedUrl("DeferredComponentFixture.qml"),
            properties: { value: 1, label: "base" }
        })
        const object = deferred.createObject(null, { label: "override" })
        verify(!!object)
        compare(object.value, 1)
        compare(object.label, "override")
        compare(deferred.properties.label, "base")
        object.destroy()
    }

    function test_live_binding_property() {
        const holder = createTemporaryQmlObject("import QtQml; QtObject { property int v: 3 }", testCase)
        const deferred = createDeferred({
            source: Qt.resolvedUrl("DeferredComponentFixture.qml"),
            properties: { value: Qt.binding(() => holder.v) }
        })
        const object = deferred.createObject(null)
        compare(object.value, 3)
        holder.v = 5
        compare(object.value, 5)
        object.destroy()
    }

    function test_component_and_adopt() {
        const deferred = createDeferred({ module: "QtQuick", typeName: "Item" })
        const c = deferred.component()
        compare(c.status, Component.Ready)
        compare(deferred.createdSpy.count, 0)
        const object = c.createObject(testCase)
        deferred.adopt(object)
        compare(deferred.createdSpy.count, 1)
        compare(deferred.createdSpy.signalArguments[0][0], object)
        object.destroy()
    }

    function test_prefetch_does_not_block_createObject() {
        const deferred = createDeferred({
            source: Qt.resolvedUrl("DeferredComponentFixture.qml"),
            prefetch: true
        })
        const object = deferred.createObject(null)
        verify(!!object)
        object.destroy()
    }

    Component {
        id: holderComponent

        QtObject {
            property QtObject ref
        }
    }

    function createPopupDeferred(props) {
        return createDeferred(Object.assign({ source: Qt.resolvedUrl("DeferredPopupFixture.qml") }, props))
    }

    function test_open_creates_each_time_by_default() {
        const deferred = createPopupDeferred({})
        const first = deferred.open(testCase)
        const second = deferred.open(testCase)
        verify(!!first && !!second)
        verify(first !== second)
        compare(first.openCount, 1)
        compare(second.openCount, 1)
        compare(deferred.createdSpy.count, 2)
        first.destroy()
        second.destroy()
    }

    function test_open_passes_params() {
        const deferred = createPopupDeferred({ properties: { value: 1 } })
        const object = deferred.open(testCase, { value: 2 })
        compare(object.value, 2)
        object.destroy()
    }

    function test_single_reuses_instance() {
        const deferred = createPopupDeferred({ single: true })
        const first = deferred.open(testCase)
        const second = deferred.open(testCase)
        compare(second, first)
        compare(first.openCount, 2)
        compare(deferred.createdSpy.count, 1)
        compare(deferred.instance, first)
        compare(deferred.createObject(testCase), first)
        first.destroy()
    }

    function test_destroyInstance_clears_instance_at_once() {
        const deferred = createPopupDeferred({ single: true })
        const holder = createTemporaryObject(holderComponent, testCase)
        const first = deferred.open(testCase)
        holder.ref = first

        deferred.destroyInstance()
        compare(deferred.instance, null)

        const second = deferred.open(testCase)
        verify(!!second)
        verify(second !== first)
        compare(deferred.instance, second)
        compare(deferred.createdSpy.count, 2)
        tryCompare(holder, "ref", null)
        compare(deferred.instance, second)
        second.destroy()
    }

    function test_destroyInstance_without_instance() {
        const deferred = createPopupDeferred({ single: true })
        deferred.destroyInstance()
        compare(deferred.instance, null)
    }

    function test_destroyOnClose() {
        const deferred = createPopupDeferred({ single: true, destroyOnClose: true })
        const holder = createTemporaryObject(holderComponent, testCase)
        const first = deferred.open(testCase)
        holder.ref = first

        first.close()
        compare(deferred.instance, null)
        tryCompare(holder, "ref", null)

        const second = deferred.open(testCase)
        verify(!!second)
        compare(deferred.createdSpy.count, 2)
        second.destroy()
    }

    function test_destroyOnClose_after_component_destroyed() {
        const deferred = createDeferred({ module: "QtQuick.Controls", typeName: "Popup", destroyOnClose: true })
        const holder = createTemporaryObject(holderComponent, testCase)
        const popup = deferred.open(testCase)
        holder.ref = popup
        tryCompare(popup, "opened", true)

        const deferredHolder = createTemporaryObject(holderComponent, testCase)
        deferredHolder.ref = deferred
        deferred.destroy()
        tryCompare(deferredHolder, "ref", null)

        failOnWarning(/.*/)
        popup.close()
        tryCompare(holder, "ref", null)
    }

    function test_close_keeps_object_by_default() {
        const deferred = createPopupDeferred({ single: true })
        const object = deferred.open(testCase)
        object.close()
        compare(deferred.instance, object)
        compare(deferred.open(testCase), object)
        object.destroy()
    }

    function test_instance_nulls_on_external_delete() {
        const deferred = createPopupDeferred({ single: true })
        const first = deferred.open(testCase)
        first.destroy()
        tryCompare(deferred, "instance", null)

        const second = deferred.open(testCase)
        verify(!!second)
        compare(deferred.createdSpy.count, 2)
        second.destroy()
    }

    function test_error_data() {
        return [
            { tag: "source", props: { source: Qt.resolvedUrl("DoesNotExist.qml") } },
            { tag: "module", props: { module: "DoesNot.Exist", typeName: "Foo" } }
        ]
    }

    function test_error(data) {
        const deferred = createDeferred(data.props)
        ignoreWarning(/DeferredComponent:/)
        compare(deferred.createObject(testCase), null)
        compare(deferred.createdSpy.count, 0)
    }
}
