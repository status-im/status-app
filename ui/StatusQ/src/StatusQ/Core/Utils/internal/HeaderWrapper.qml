pragma ComponentBehavior: Bound

import QtQuick
import QtQml

// This component is implementation detail of DoubleFlickableWithFolding
// Moved to external file instead of using inline component because a bug
// in Qt 5.15.2 causing tests crash.
Item {
    property Flickable flickable

    z: 1

    Binding {
        when: flickable.headerItem
        target: flickable.headerItem
        property: "parent"
        value: container
        restoreMode: Binding.RestoreBindingOrValue
    }

    Binding {
        when: flickable.headerItem
        target: container
        property: "y"
        value: -flickable.headerItem.y
        restoreMode: Binding.RestoreBindingOrValue
    }

    Item { id: container }
}
