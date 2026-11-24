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
