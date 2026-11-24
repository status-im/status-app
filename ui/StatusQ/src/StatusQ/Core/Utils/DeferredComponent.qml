import QtQml

/*!
   \qmltype DeferredComponent
   \inqmlmodule StatusQ.Core.Utils
   \brief Creates objects of a QML type that is loaded on first use.

   Unlike \c {Component { Foo {} }}, naming the type by URL, or by module and type name, keeps
   \c Foo and everything it imports out of the declaring document's type closure, so
   the type is not loaded (nor precompiled) until the first \l createObject() call.

   \qml
   DeferredComponent {
       id: createCommunityPopupComponent
       module: "AppLayouts.Communities.popups"
       typeName: "CreateCommunityPopup"
       properties: ({ store: root.communitiesStore, loading: Qt.binding(() => root.loading) })
       onCreated: popup => popup.closed.connect(popup.destroy)
   }
   \endqml

   It mirrors \c Component.createObject(), so it can be passed wherever a component
   is only used through that function.
*/
QtObject {
    id: root

    // either the document's URL, or module + typeName
    property url source
    property string module
    property string typeName

    // initial properties of every created object; use Qt.binding() for live values
    property var properties: ({})

    // load the type in the background right after creation, so the first use does not wait
    property bool prefetch: false

    signal created(var object)

    function component(mode = Component.PreferSynchronous) {
        const c = root.source.toString() !== "" ? Qt.createComponent(root.source, mode)
                                                : Qt.createComponent(root.module, root.typeName, mode)
        if (c.status === Component.Error)
            console.warn("DeferredComponent:", c.errorString())
        return c
    }

    // for objects created from component() by someone else, e.g. a StackView
    function adopt(object) {
        root.created(object)
    }

    function createObject(parent, params = {}) {
        const c = root.component()
        if (c.status !== Component.Ready)
            return null
        const object = c.createObject(parent, Object.assign({}, root.properties, params))
        if (!object) {
            console.warn("DeferredComponent: cannot create", c.url, c.errorString())
            return null
        }
        root.adopt(object)
        return object
    }

    Component.onCompleted: {
        if (root.prefetch)
            Qt.callLater(() => d.prefetched = root.component(Component.Asynchronous))
    }

    readonly property QtObject _d: QtObject {
        id: d

        property Component prefetched
    }
}
