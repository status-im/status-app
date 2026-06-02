import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts
import QtQuick.Window
import Qt5Compat.GraphicalEffects

import StatusQ.Core
import StatusQ.Core.Theme

ToolBar {
    id: root

    readonly property alias headline: headline
    readonly property alias actions: actions
    property bool dropShadowEnabled
    property bool showDivider: true

    property alias leftComponent: leftComponentLoader.sourceComponent

    property bool internalPopupActive
    property color internalOverlayColor
    property int popupFullHeight
    property Component internalPopupComponent

    property color color: Theme.palette.statusModal.backgroundColor
    property int radius: Theme.radius
    
    signal closeInternalPopup()

    position: ToolBar.Top
    background: StatusDialogBackground {
        color: root.color
        topLeftRadius: root.radius
        topRightRadius: root.radius
        bottomLeftRadius: 0
        bottomRightRadius: 0
    }

    Item {
        id: content
        anchors.fill: parent

        implicitHeight: layout.implicitHeight + layout.anchors.topMargin + layout.anchors.bottomMargin
        implicitWidth: layout.implicitWidth + layout.anchors.leftMargin + layout.anchors.rightMargin

        RowLayout {
            id: layout

            clip: true

            anchors {
                fill: parent
                margins: Theme.defaultPadding
            }

            spacing: Theme.halfPadding

            Loader {
                id: leftComponentLoader

                Layout.fillHeight: true
                visible: sourceComponent
            }

            StatusTitleSubtitle {
                id: headline

                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            StatusHeaderActions {
                id: actions

                Layout.alignment: Qt.AlignTop
            }
        }

        StatusDialogDivider {
            anchors.bottom: parent.bottom
            width: parent.width
            visible: root.showDivider
        }

        Rectangle {
            id: internalOverlay
            anchors.fill: parent
            anchors.bottomMargin: -1 * root.popupFullHeight + root.height
            visible: root.internalPopupActive
            radius: root.radius
            color: root.internalOverlayColor

            StatusMouseArea {
                anchors.fill: parent
                anchors.bottomMargin: popupLoader.height
                onClicked: {
                    root.closeInternalPopup()
                }
            }
        }

        Loader {
            id: popupLoader
            anchors.bottom: parent.bottom
            anchors.bottomMargin: internalOverlay.anchors.bottomMargin
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, parent.width, root.Window ? root.Window.width : parent.width)
            height: Math.min(implicitHeight, Math.max(0, root.popupFullHeight))
            active: root.internalPopupActive
            sourceComponent: root.internalPopupComponent
        }
    }
    layer.enabled: root.dropShadowEnabled
    layer.effect: DropShadow {
        horizontalOffset: 0
        verticalOffset: 2
        samples: 37
        color: Theme.palette.dropShadow
    }
}
