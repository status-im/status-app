import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models
import Qt5Compat.GraphicalEffects

import StatusQ.Core
import StatusQ.Core.Theme

Control {
    id: root

    property ObjectModel leftButtons
    property ObjectModel rightButtons
    property ObjectModel errorTags
    property color color: Theme.palette.statusModal.backgroundColor
    property bool dropShadowEnabled
    property bool bottomSheet

    spacing: Theme.defaultHalfPadding
    padding: Theme.defaultPadding
    bottomPadding: padding + root.parent.SafeArea.margins.bottom

    background: Rectangle {
        color: root.color
        bottomLeftRadius: root.bottomSheet ? 0 : Theme.radius
        bottomRightRadius: root.bottomSheet ? 0 : Theme.radius
        topLeftRadius: 0
        topRightRadius: 0

        layer.enabled: root.dropShadowEnabled
        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: -2
            samples: 37
            color: Theme.palette.dropShadow
        }

        StatusDialogDivider {
            anchors.top: parent.top
            width: parent.width
            visible: !root.dropShadowEnabled
        }
    }

    contentItem: ColumnLayout {
        id: layout

        spacing: Theme.halfPadding

        Repeater {
            Layout.topMargin: 4
            model: root.errorTags
            onItemAdded: function(index, item) {
                item.Layout.fillHeight = true
                item.Layout.fillWidth = true
            }
        }

        StatusDialogDivider {
            Layout.topMargin: 12
            Layout.fillWidth: true

            color: Theme.palette.directColor8

            visible: !!root.errorTags && root.errorTags.count > 0
        }

        RowLayout {

            Layout.fillWidth: true

            spacing: root.spacing
            clip: true

            Repeater {
                model: root.leftButtons
                onItemAdded: function(index, item) {
                    item.Layout.fillHeight = true
                    item.Layout.fillWidth = Qt.binding(() => root.width < root.implicitWidth)
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Repeater {
                model: root.rightButtons
                onItemAdded: function(index, item) {
                    item.Layout.fillHeight = true
                    item.Layout.fillWidth = Qt.binding(() => root.width < root.implicitWidth)
                }
            }
        }
    }
}
