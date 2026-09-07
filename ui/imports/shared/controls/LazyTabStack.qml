import QtQuick

/// One loader per tab: a view is created when its tab is first selected and
/// kept alive, so switching back to it only toggles visibility.
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

        readonly property Loader currentLoader: {
            repeater.count
            return repeater.itemAt(root.currentIndex) as Loader
        }
    }

    Repeater {
        id: repeater

        model: root.tabComponents.length

        delegate: Loader {
            id: loader

            required property int index
            readonly property bool current: root.currentIndex === loader.index
            property bool activated: false

            anchors.fill: parent
            asynchronous: root.asynchronous
            active: loader.activated
            visible: loader.current && loader.status === Loader.Ready
            sourceComponent: root.tabComponents[loader.index]

            onCurrentChanged: if (loader.current) loader.activated = true
            Component.onCompleted: if (loader.current) loader.activated = true
        }
    }
}
