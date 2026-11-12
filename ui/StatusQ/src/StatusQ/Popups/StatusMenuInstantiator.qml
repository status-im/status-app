import QtQuick
import QtQuick.Controls
import QtQml.Models

Instantiator {
    id: root

    property var menu
    property int indexOffset: 0

    onObjectAdded: function(index, object) {
        if (object instanceof Menu)
            menu.insertMenu(root.indexOffset + index, object)
        else if (object instanceof Action)
            menu.insertAction(root.indexOffset + index, object)
        else
            menu.insertItem(root.indexOffset + index, object)
    }

    onObjectRemoved: function(index, object) {
        if (object instanceof Menu)
            menu.removeMenu(object)
        else if (object instanceof Action)
            menu.removeAction(object)
        else
            menu.removeItem(object)
    }
}
