import QtQuick
import QtQuick.Controls
import QtQml.Models

Instantiator {
    id: root

    property var menu

    onObjectAdded: function(index, object) {
        if (object instanceof Menu)
            menu.addMenu(object)
        else if (object instanceof Action)
            menu.addAction(object)
        else
            menu.addItem(object)
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
