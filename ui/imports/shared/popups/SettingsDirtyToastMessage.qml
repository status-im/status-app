import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Qt5Compat.GraphicalEffects

import utils

import shared.controls
import shared.panels

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

Control {
    id: root

    property bool loading: false
    property bool active: false
    property bool cancelButtonVisible: true
    property bool saveChangesButtonEnabled: false
    property bool saveForLaterButtonVisible
    property alias saveChangesText: saveChangesButton.text
    property string saveChangesTooltipText
    property alias saveForLaterText: saveForLaterButton.text
    property alias cancelChangesText: cancelChangesButton.text
    property alias changesDetectedText: changesDetectedTextItem.text
    property alias additionalComponent: additionalTextComponent

    readonly property string defaultChangesDetectedText: qsTr("Changes detected")
    readonly property string defaultSaveChangesText: qsTr("Save changes")
    readonly property string defaultSaveForLaterText: qsTr("Save for later")
    readonly property string defaultCancelChangesText: qsTr("Cancel")

    property Flickable flickable: null

    enum Type {
        Danger,
        Info
    }
    property int type: SettingsDirtyToastMessage.Type.Danger

    signal saveChangesClicked
    signal saveForLaterClicked
    signal resetChangesClicked

    function notifyDirty() {
        toastAlertAnimation.running = true
        saveChangesButton.forceActiveFocus()
    }

    padding: Theme.padding

    opacity: active ? 1 : 0

    onActiveChanged: {
        if (!active || !flickable)
            return;

        const item = Window.window.activeFocusItem;
        const h1 = this.height;
        const y1 = this.mapToGlobal(0, 0).y;
        const h2 = item.height;
        const y2 = item.mapToGlobal(0, 0).y;
        const margin = 20;
        const offset = h2 - (y1 - y2);

        if (offset <= 0 || flickable.contentHeight <= 0)
            return;

        toastFlickAnimation.from = flickable.contentY;
        toastFlickAnimation.to = flickable.contentY + offset + margin;
        toastFlickAnimation.start()
    }

    NumberAnimation {
        id: toastFlickAnimation
        target: root.flickable
        property: "contentY"
        duration: 150
        easing.type: Easing.InOutQuad
    }

    Behavior on opacity {
        NumberAnimation {}
    }

    background: Rectangle {
        id: backgroundRect

        color: Theme.palette.statusToastMessage.backgroundColor
        radius: 8
        border.color: root.type === SettingsDirtyToastMessage.Type.Danger
                      ? Theme.palette.dangerColor2 : Theme.palette.primaryColor2
        border.width: 2

        layer.enabled: true
        layer.effect: DropShadow {
            verticalOffset: 3
            radius: 8
            samples: 15
            fast: true
            cached: true
            color: backgroundRect.border.color
            spread: 0.1
        }

        NumberAnimation on border.width {
            id: toastAlertAnimation
            from: 0
            to: 4
            loops: 2
            duration: 600
            onFinished: backgroundRect.border.width = 2
        }

        StatusMouseArea {
            anchors.fill: parent
            visible: root.active // This is required not to change cursorShape
            enabled: root.active
            hoverEnabled: true
        }
    }

    contentItem: ColumnLayout {
        id: toastContent
        spacing: Theme.padding

        RowLayout {
            Layout.alignment: Qt.AlignHCenter

            StatusBaseText {
                id: changesDetectedTextItem
                Layout.fillWidth: true
                padding: 8
                horizontalAlignment: Text.AlignHCenter
                color: Theme.palette.directColor1
                text: root.defaultChangesDetectedText
            }

            StatusButton {
                id: cancelChangesButton
                text: root.defaultCancelChangesText
                enabled: !root.loading && root.active
                visible: root.cancelButtonVisible
                type: StatusBaseButton.Type.Danger
                onClicked: root.resetChangesClicked()
            }

            StatusFlatButton {
                id: saveForLaterButton
                text: root.defaultSaveForLaterText
                loading: root.loading
                enabled: root.active && root.saveChangesButtonEnabled
                visible: root.saveForLaterButtonVisible
                onClicked: root.saveForLaterClicked()
            }

            StatusButton {
                id: saveChangesButton

                objectName: "settingsDirtyToastMessageSaveButton"
                loading: root.loading
                text: root.defaultSaveChangesText
                interactive: root.active && root.saveChangesButtonEnabled
                tooltip.text: root.saveChangesTooltipText
                onClicked: root.saveChangesClicked()
            }
        }

        Separator {
            id: separator
            Layout.fillWidth: true

            visible: additionalTextComponent.visible
        }

        StatusBaseText {
            id: additionalTextComponent

            Layout.alignment: Qt.AlignHCenter

            font.pixelSize: Theme.tertiaryTextFontSize
            visible: false
        }
    }
}
