import QtQuick 2.15
import StatusQ.Controls 0.1

import StatusQ.Core.Utils as SQUtils

Item {
    id: root

    property url source: ""

    Component {
        id: nativeImplComponent
        NativeIndicatorItem {
            x: root.x
            y: root.y
            width: root.width
            height: root.height
            visible: root.visible
            enabled: root.enabled
            source: root.source
        }
    }

    Component {
        id: qmlImplComponent
        NativeIndicatorImpl {
            anchors.fill: parent
            visible: root.visible
            enabled: root.enabled
            source: root.source
        }
    }

    QtObject {
        id: d
        readonly property bool useNative: SQUtils.isMobile || SQUtils.isMacOS
        property var implItem: null

        function destroyImpl() {
            if (d.implItem) {
                d.implItem.destroy()
                d.implItem = null
            }
        }

        function createImpl() {
            const component = d.useNative ? nativeImplComponent : qmlImplComponent
            const p = d.useNative ? root.parent : root
            if (!p) {
                d.destroyImpl()
                return
            }

            // Avoid double-create during startup.
            if (d.implItem && d.implItem.parent === p) return

            d.destroyImpl()
            d.implItem = component.createObject(p)
        }

        onUseNativeChanged: d.createImpl()
    }

    Component.onCompleted: d.createImpl()
    onParentChanged: d.createImpl()
    Component.onDestruction: d.destroyImpl()
}


