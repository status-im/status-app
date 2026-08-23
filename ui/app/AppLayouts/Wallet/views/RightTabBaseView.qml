import QtQuick
import QtQuick.Layouts

import StatusQ.Core.Theme

FocusScope {
    id: root

    property Item header
    default property Item content

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.bigPadding

        LayoutItemProxy {
            id: headerWrapper

            target: root.header
            visible: !!target

            Layout.fillWidth: true
            Layout.leftMargin: Theme.bigPadding
            Layout.rightMargin: Theme.bigPadding
        }

        LayoutItemProxy {
            id: contentWrapper

            target: root.content

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Theme.bigPadding
            Layout.rightMargin: Theme.bigPadding
        }
    }
}
