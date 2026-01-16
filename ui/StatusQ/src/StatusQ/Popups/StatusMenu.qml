import QtQuick
import QtQml
import QtQuick.Controls
import QtQuick.Controls.Universal
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Popups

/*!
    To create menu elements from a model, use Instantiator:

    \qml
        StatusMenu {
            id: myMenu

            StatusMenuInstantiator {
                model: myModel
                menu: myMenu
                delegate: StatusAction {
                    text: model.text
                    assetSettings.name: model.iconName
                    onTriggered: {
                        popupMenu.dismiss()
                    }
                }
            }
        }
    \endqml
 */

Menu {
    id: root

    property real maxImplicitWidth: 640
    readonly property color defaultIconColor: Theme.palette.primaryColor1

    property int type: StatusAction.Type.Normal

    property StatusAssetSettings assetSettings: StatusAssetSettings {
        width: 18
        height: 18
        rotation: 0
        isLetterIdenticon: false
        isImage: false
        color: {
            if (!root.enabled)
                return Theme.palette.baseColor1
            if (root.type === StatusAction.Type.Danger)
                return Theme.palette.dangerColor1
            if (root.type === StatusAction.Type.Success)
                return Theme.palette.successColor1
            return Theme.palette.primaryColor1
        }
    }

    property StatusFontSettings fontSettings: StatusFontSettings {}

    property bool hideDisabledItems: true

    property bool visualizeShortcuts

    property var openHandler
    property var closeHandler

    dim: false
    closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
    verticalPadding: Theme.halfPadding
    horizontalPadding: 0

    QtObject {
        id: d
        readonly property var window: root.contentItem.Window.window
    }

    leftMargin: Theme.padding + (d.window?.SafeArea.margins.left ?? 0)
    rightMargin: Theme.padding + (d.window?.SafeArea.margins.right ?? 0)
    topMargin: Theme.padding + (d.window?.SafeArea.margins.top ?? 0)
    bottomMargin: Theme.padding + (d.window?.SafeArea.margins.bottom ?? 0)

    onOpened: {
        if (typeof openHandler === "function") {
            openHandler()
        }
    }

    onClosed: {
        if (typeof closeHandler === "function") {
            closeHandler()
        }
    }

    delegate: StatusMenuItem {
        visible: root.hideDisabledItems && !visibleOnDisabled ? enabled : true
        height: visible ? implicitHeight : 0
        visualizeShortcuts: root.visualizeShortcuts
    }

    contentItem: StatusScrollView {
        id: scrollView
        padding: 0

        ColumnLayout {
            spacing: 0

            width: root.availableWidth

            Repeater {
                model: root.contentModel

                onItemAdded: (index, item) => {
                    item.Layout.fillWidth = true
                    item.Layout.minimumWidth = scrollView.width
                    item.Layout.maximumWidth = root.maxImplicitWidth
                }
            }
        }
    }

    background: Rectangle {
        id: backgroundContent
        implicitWidth: 176
        color: Theme.palette.statusMenu.backgroundColor
        radius: Theme.radius
        layer.enabled: true
        layer.effect: DropShadow {
            width: backgroundContent.width
            height: backgroundContent.height
            x: backgroundContent.x
            visible: backgroundContent.visible
            source: backgroundContent
            horizontalOffset: 0
            verticalOffset: 4
            radius: 12
            samples: 25
            spread: 0.2
            color: Theme.palette.dropShadow
        }
    }
}
