pragma ComponentBehavior: Bound

import QtQuick
import StatusQ

// Experimental sibling, not used by application rows. Publish headerData as
// one immutable value with copied primitive fields; replace the whole value
// when sender/message data changes. Do not put a mutable sender QObject in it.
MessageHeaderItem {
    id: root
    required services
    objectName: "nativeHeaderRenderer"

    signal clicked(var sender)
    readonly property alias clockTimestamp: root.rawTimestamp
    readonly property alias timestampLabel: root.timestampText
    onNameClicked: root.clicked(root)
    Accessible.role: Accessible.StaticText
    Accessible.name: accessibleText
}
