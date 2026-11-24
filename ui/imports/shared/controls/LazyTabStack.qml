import QtQuick

/// One loader per tab: a view is created when its tab is first selected and
/// kept alive, so switching back to it only toggles visibility.
/// A tab is a Component, or a DeferredComponent with a `source` URL.
Item {
    id: root

    required property var tabComponents
    property int currentIndex: 0
    property bool asynchronous: true

    readonly property bool currentReady: d.currentLoader?.status === Loader.Ready

    function itemAt(index) {
        const loader = repeater.itemAt(index) as Loader
        return loader ? loader.item : null
    }

    QtObject {
        id: d

        property Loader currentLoader: null
    }

    Repeater {
        id: repeater

        model: root.tabComponents.length

        delegate: Loader {
            id: loader

            required property int index
            readonly property bool current: root.currentIndex === loader.index
            readonly property var tab: root.tabComponents[loader.index]
            readonly property bool deferred: typeof loader.tab?.adopt === "function"
            property bool activated: false

            anchors.fill: parent
            asynchronous: root.asynchronous
            active: loader.activated
            visible: loader.current && loader.status === Loader.Ready
            sourceComponent: loader.deferred ? undefined : loader.tab

            function takeOver() {
                if (!loader.current)
                    return
                loader.activated = true
                d.currentLoader = loader
            }

            onCurrentChanged: takeOver()
            onLoaded: {
                if (loader.deferred)
                    loader.tab.adopt(loader.item)
            }
            Component.onCompleted: {
                if (loader.deferred)
                    loader.setSource(loader.tab.source, loader.tab.properties)
                takeOver()
            }
        }
    }
}
