import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils
import shared.popups

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

FocusScope {
    id: root

    property string sectionTitle
    property int contentWidth
    readonly property int contentHeight: root.height - titleRow.height - Theme.padding

    property alias titleRowLeftComponentLoader: leftLoader
    property alias titleRowComponentLoader: additionalTitleActionsLoader
    property list<Item> headerComponents
    property alias bottomHeaderComponents: secondHeaderRow.contentItem
    default property alias content: contentWrapper.data
    property alias titleLayout: titleLayout

    property bool stickTitleRowComponentLoader: false

    property bool dirty: false

    // Used to configure the dirty behaviour of the settings page as a must blocker notification when
    // user wants to leave the current page or just, ignore the changes done. Default: blocker
    property bool ignoreDirty: false

    property bool saveChangesButtonEnabled: false
    readonly property alias toast: settingsDirtyToastMessage

    // Used to configure the dirty toast behaviour (by default overlay on top of content)
    property bool autoscrollWhenDirty: false

    readonly property real availableHeight:
        scrollView.availableHeight - settingsDirtyToastMessagePlaceholder.height
        - Theme.bigPadding

    signal baseAreaClicked()
    signal saveChangesClicked()
    signal saveForLaterClicked()
    signal resetChangesClicked()

    function notifyDirty() {
        settingsDirtyToastMessage.notifyDirty();
    }

    QtObject {
        id: d

        readonly property int titleRowHeight: 56
        readonly property int bottomDirtyToastMargin: 36

        // Read-only flag that turns true when the row component enters a “compact” layout automatically on resize.
        readonly property bool compactRowMode: sectionTitleText.implicitWidth + titleFirstRowItem.implicitWidth + 2 * root.Theme.padding > root.contentWidth
    }

    Loader {
        id: additionalTitleActionsLoader
        visible: false
    }

    StatusMouseArea {
        anchors.fill: parent
        propagateComposedEvents: true
        onClicked: { root.baseAreaClicked() }
    }

    Component.onCompleted: {
        if (headerComponents.length) {
            for (let i in headerComponents) {
                headerComponents[i].parent = titleRow
            }
        }
    }

    ColumnLayout {
        id: titleRow
        width: root.contentWidth
        spacing: 0

        RowLayout {
            id: titleLayout
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? d.titleRowHeight : 0
            visible: (root.sectionTitle !== "")

            Loader {
                id: leftLoader
            }

            StatusBaseText {
                id: sectionTitleText
                Layout.fillWidth: !root.stickTitleRowComponentLoader
                text: root.sectionTitle
                font.weight: Font.Bold
                font.pixelSize: root.Theme.fontSize(28) // Keep as is - special case for main header
                color: Theme.palette.directColor1

                elide: Text.ElideRight
            }

            // filler
            Item {
                Layout.fillWidth: true
            }

            LayoutItemProxy {
                id: titleFirstRowItem
                visible: !d.compactRowMode

                Layout.leftMargin: root.stickTitleRowComponentLoader ? 8 : 0

                target: additionalTitleActionsLoader.item
            }
        }

        LayoutItemProxy {
            visible: d.compactRowMode

            target: additionalTitleActionsLoader.item
        }

        Control {
            id: secondHeaderRow
            Layout.fillWidth: true
            visible: !!contentItem
        }
    }

    StatusScrollView {
        id: scrollView
        objectName: "settingsContentBaseScrollView"
        anchors.top: titleRow.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: titleLayout.visible ? Theme.padding: 0
        padding: 0
        width: root.width
        contentWidth: root.contentWidth
        contentHeight: contentLayout.implicitHeight + Theme.bigPadding

        Column {
            id: contentLayout
            width: scrollView.availableWidth

            StatusMouseArea {
                onClicked: root.baseAreaClicked()
                width: contentWrapper.implicitWidth
                height: contentWrapper.implicitHeight
                hoverEnabled: true
                propagateComposedEvents: true

                Column {
                    id: contentWrapper
                    onVisibleChanged: if (visible) forceActiveFocus()
                }
            }

            // Used only when dirty toast visible and in case of autoscrolling configuration
            Item {
                id: settingsDirtyToastMessagePlaceholder

                width: settingsDirtyToastMessage.implicitWidth
                height: settingsDirtyToastMessage.active && root.autoscrollWhenDirty ?
                            (settingsDirtyToastMessage.implicitHeight + d.bottomDirtyToastMargin) : 0 /*Overlay on top of content*/

                Behavior on implicitHeight {
                    enabled: root.autoscrollWhenDirty
                    NumberAnimation {
                        duration: ThemeUtils.AnimationDuration.Fast
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }

    Connections {
        target: scrollView.flickable

        function scrollToFocusedItem() {
            const focusedItem = root.Window.activeFocusItem
            if (!focusedItem)
                return
            const contentItem = scrollView.flickable.contentItem
            const rect = contentItem.mapFromItem(
                focusedItem, Qt.rect(0, 0, focusedItem.width, focusedItem.height))
            SQUtils.Utils.ensureVisible(scrollView.flickable,
                                Qt.rect(0, rect.y, contentItem.width, rect.height))
        }

        function onContentHeightChanged() {
            scrollToFocusedItem()
        }

        function onHeightChanged() {
            scrollToFocusedItem()
        }
    }

    SettingsDirtyToastMessage {
        id: settingsDirtyToastMessage

        anchors.bottom: scrollView.bottom
        anchors.bottomMargin: d.bottomDirtyToastMargin
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, parent.width - 2 * Theme.padding)

        visible: active
        active: root.dirty
        flickable: root.autoscrollWhenDirty ? scrollView.flickable : null
        saveChangesButtonEnabled: root.saveChangesButtonEnabled
        onResetChangesClicked: root.resetChangesClicked()
        onSaveChangesClicked: root.saveChangesClicked()
        onSaveForLaterClicked: root.saveForLaterClicked()
    }
}
