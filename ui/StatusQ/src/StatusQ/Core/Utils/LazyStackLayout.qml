pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

/*!
   \qmltype LazyStackLayout
   \inherits StackLayout
   \inqmlmodule StatusQ.Core.Utils
   \since StatusQ.Core.Utils 0.1

   \brief A component similar to StackLayout but operating on Component objects.
   Those objects are instantiated when given index is accessed first time.
   Therefore only one item is instantiated on startup, instantiation of others
   is deferred, potentially resulting with more responsive UI.
*/
StackLayout {
    id: root

    default property list<Component> children

    readonly property Item currentItem:
        repeater.count ? repeater.itemAt(currentIndex).item : null

    Repeater {
        id: repeater

        model: root.children.length

        delegate: Loader {
            active: false
            sourceComponent: root.children[model.index]

            onVisibleChanged: {
                if (visible)
                    active = true
            }

            Component.onCompleted: active = visible
        }
    }
}
