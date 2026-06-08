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

    // When true the available width is too small to fit the label and the
    // buttons in a single row, so the buttons reflow onto a second row below.
    readonly property bool compact: root.availableWidth < d.oneRowContentWidth

    function notifyDirty() {
        toastAlertAnimation.running = true
        saveChangesButton.forceActiveFocus()
    }

    padding: Theme.padding

    // Pinned to the natural one-row width so it stays constant across the
    // compact/non-compact reflow - this keeps callers that rely on implicitWidth
    // stable and avoids a binding loop with width-constrained call sites.
    implicitWidth: leftPadding + rightPadding +
                   Math.max(d.oneRowContentWidth, additionalTextComponent.implicitWidth)

    opacity: active ? 1 : 0

    QtObject {
        id: d

        // Intrinsic (column-independent) width needed to lay out the label and
        // the buttons side by side. Invisible buttons contribute 0.
        readonly property real oneRowContentWidth: changesDetectedTextItem.implicitWidth
                                                    + buttonsRow.implicitWidth
                                                    + topGrid.columnSpacing
    }

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
        radius: Theme.radius
        border.color: root.type === SettingsDirtyToastMessage.Type.Danger
                      ? Theme.palette.dangerColor2 : Theme.palette.primaryColor2
        border.width: 2

        layer.enabled: true
        layer.effect: DropShadow {
            verticalOffset: 3
            radius: Theme.radius
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
    }

    contentItem: ColumnLayout {
        id: toastContent
        spacing: Theme.padding

        GridLayout {
            id: topGrid
            Layout.fillWidth: true

            columns: root.compact ? 1 : 2
            columnSpacing: Theme.halfPadding
            rowSpacing: Theme.halfPadding

            StatusBaseText {
                id: changesDetectedTextItem
                Layout.fillWidth: true
                padding: 8
                horizontalAlignment: Text.AlignHCenter
                color: Theme.palette.directColor1
                text: root.defaultChangesDetectedText
            }

            RowLayout {
                id: buttonsRow

                // Always right-aligned and packed together. The row is sized to
                // its content when the buttons fit, so there is no extra space
                // between them.
                Layout.alignment: (root.compact ? Qt.AlignCenter : Qt.AlignRight) | Qt.AlignVCenter
                // Never exceed the toast content width, so when the buttons don't
                // fit the row is clamped and the fillWidth buttons shrink, eliding
                // their text instead of overflowing.
                Layout.maximumWidth: root.availableWidth
                Layout.fillWidth: false

                spacing: Theme.bigPadding

                StatusButton {
                    id: cancelChangesButton
                    Layout.fillWidth: true
                    Layout.maximumWidth: implicitWidth
                    text: root.defaultCancelChangesText
                    enabled: !root.loading && root.active
                    visible: root.cancelButtonVisible
                    type: StatusBaseButton.Type.Danger
                    onClicked: root.resetChangesClicked()
                }

                StatusFlatButton {
                    id: saveForLaterButton
                    Layout.fillWidth: true
                    Layout.maximumWidth: implicitWidth
                    text: root.defaultSaveForLaterText
                    loading: root.loading
                    enabled: root.active && root.saveChangesButtonEnabled
                    visible: root.saveForLaterButtonVisible
                    onClicked: root.saveForLaterClicked()
                }

                StatusButton {
                    id: saveChangesButton
                    Layout.fillWidth: true
                    Layout.maximumWidth: implicitWidth

                    objectName: "settingsDirtyToastMessageSaveButton"
                    loading: root.loading
                    text: root.defaultSaveChangesText
                    interactive: root.active && root.saveChangesButtonEnabled
                    tooltip.text: root.saveChangesTooltipText
                    onClicked: root.saveChangesClicked()
                }
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
