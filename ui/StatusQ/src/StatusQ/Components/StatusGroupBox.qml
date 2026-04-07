pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Core


GroupBox {
    id: root

    topPadding: label.implicitHeight
    leftPadding: 16

    /*!
       \qmlproperty string StatusGroupBox::icon
       This property holds the icon name for the icon represented on top of the
       component as a title icon.
    */
    property string icon

    /*!
       \qmlproperty int StatusItemSelector::iconSize
       This property holds the icon size for the icon represented on top of the
       component as a title icon.
    */
    property int iconSize: 24

    background: Rectangle {
        color: Theme.palette.baseColor4
        radius: 16
    }

    label: Control {
        x: root.leftPadding
        width: root.availableWidth
        topPadding: 12
        bottomPadding: 12

        contentItem: RowLayout {
            spacing: 8

            StatusIcon {
                sourceSize.width: width || undefined
                sourceSize.height: height || undefined
                antialiasing: true
                width: root.iconSize
                height: width
                icon: root.icon
                color: enabled ? "transparent" : Theme.palette.baseColor1
            }

            StatusBaseText {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true

                text: root.title
                font.pixelSize: Theme.secondaryAdditionalTextSize
                color: enabled ? Theme.palette.directColor1 : Theme.palette.baseColor1
                elide: Text.ElideRight
            }
        }
    }
}
