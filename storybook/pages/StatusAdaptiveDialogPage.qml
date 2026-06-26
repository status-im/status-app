import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import Storybook

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Popups.Dialog

import AppLayouts.Wallet.controls

SplitView {
    id: root

    orientation: Qt.Horizontal

    Logs {
        id: logs
    }

    QtObject {
        id: d

        // Derived state used by the controls below to keep the dialog bindings compact.
        readonly property bool longContent: contentMode.currentValue === "long"
        readonly property bool dialogBottomSheet: dialog.width === root.width && dialog.y > root.height / 2

        // Header presets: title/subtitle/image/action combinations can be mixed independently.
        readonly property bool headerHasTitle: headerMode.currentValue !== "none"
        readonly property bool headerHasSubtitle: headerMode.currentValue === "title-subtitle"
                                             || headerMode.currentValue === "image-title-subtitle"
        readonly property bool headerHasImage: headerMode.currentValue === "image-title"
                                          || headerMode.currentValue === "image-title-subtitle"
        readonly property bool headerHasCloseAction: headerActionsMode.currentValue === "close"
                                                || headerActionsMode.currentValue === "both"
                                                || headerActionsMode.currentValue === "close-custom"
        readonly property bool headerHasInfoAction: headerActionsMode.currentValue === "info"
                                               || headerActionsMode.currentValue === "both"
        readonly property bool headerHasCustomActions: headerActionsMode.currentValue === "custom"
                                                  || headerActionsMode.currentValue === "close-custom"
        readonly property real controlsSectionSpacing: Math.max(Theme.halfPadding, 8)

        // Footer presets: each mode resolves to the models consumed by StatusAdaptiveDialog.
        readonly property var footerLeftModel: {
            switch (footerButtonsMode.currentValue) {
                case "back-done":
                case "back-only":  return footerLeftButtonsModel
                case "info-done":  return footerLeftInfoModel
                default:           return null
            }
        }
        readonly property var footerRightButtonsModel: {
            switch (footerButtonsMode.currentValue) {
                case "cancel-done": return footerRightButtonsCancelDoneModel
                case "back-done":
                case "info-done":
                case "done-only":   return footerRightButtonsDoneModel
                default:            return null
            }
        }
        readonly property var footerErrorTagsModel: {
            switch (footerErrorsMode.currentValue) {
                case "one": return errorTagsOneModel
                case "two": return errorTagsTwoModel
                default: return null
            }
        }
    }

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        PopupBackground {
            anchors.fill: parent

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 420)
                spacing: Theme.padding

                StatusBaseText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.palette.baseColor1
                    text: "Viewport: " + Math.round(root.width) + " x " + Math.round(root.height)
                }

                StatusButton {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Open adaptive dialog"
                    onClicked: dialog.open()
                }
            }
        }

        StatusAdaptiveDialog {
            id: dialog

            // Presentation and behavior knobs.
            maximumWidthOverride: customMaxWidth.checked ? maxWidthSlider.value : 0
            maximumHeightOverride: heightCap.checked ? heightSlider.value : 0
            closeOnOverlayClick: closeOnOverlay.checked
            escapeKeyCloses: escapeCloses.checked
            internalPopupComponent: internalPopupComponent

            contentComponent: bodyComponent

            // Header API: consumers configure data and actions, not the internal toolbar.
            title: d.headerHasTitle ? "StatusAdaptiveDialog" : ""
            subtitle: d.headerHasSubtitle ? (d.dialogBottomSheet ? "Bottom sheet" : "Centered") : ""
            leftHeaderComponent: d.headerHasImage ? headerImageComponent : null
            headerCustomButtons: d.headerHasCustomActions ? customActionsModel : null
            headerActions.closeButton.visible: d.headerHasCloseAction
            headerActions.infoButton.visible: d.headerHasInfoAction
            headerActions.closeButton.onClicked: {
                logs.logEvent("StatusAdaptiveDialog::closeButtonClicked")
                dialog.close()
            }
            headerActions.infoButton.onClicked: {
                logs.logEvent("StatusAdaptiveDialog::infoButtonClicked")
                dialog.openInternalPopup()
            }

            // Footer API: left/right action groups and optional error tags.
            footerLeftButtons: d.footerLeftModel
            footerRightButtons: d.footerRightButtonsModel
            errorTags: d.footerErrorTagsModel
        }

        // Extra header action used by the "custom" header action modes.
        ObjectModel {
            id: customActionsModel

            StatusFlatRoundButton {
                type: StatusFlatRoundButton.Type.Secondary
                icon.name: "add"
                icon.color: Theme.palette.directColor1
                icon.width: 24
                icon.height: 24
                onClicked: {
                    logs.logEvent("StatusAdaptiveDialog::customActionClicked")
                    dialog.openInternalPopup()
                }
            }
        }

        Component {
            id: bodyComponent

            ColumnLayout {
                spacing: Theme.halfPadding

                Repeater {
                    model: d.longContent ? 10 : 3

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: index === 0 ? 88 : 52
                        radius: 8
                        color: index % 2 ? Theme.palette.baseColor5 : Theme.palette.baseColor4

                        StatusBaseText {
                            anchors.fill: parent
                            anchors.margins: Theme.defaultPadding
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.WordWrap
                            text: index === 0 ? "Base step: components, sizing and automatic presentation only." : "Content row " + index
                        }
                    }
                }
            }
        }

        Component {
            id: headerImageComponent

            // Mirrors the account/app icon style used by signing modals.
            StatusSmartIdenticon {
                asset.name: "filled-account"
                asset.emoji: "S"
                asset.color: Theme.palette.primaryColor1
                asset.isLetterIdenticon: true
                asset.bgWidth: 40
                asset.bgHeight: 40

                bridgeBadge.visible: true
                bridgeBadge.border.width: 2
                bridgeBadge.color: StatusColors.darkDesktopBlue10
                bridgeBadge.image.source: Assets.svg("sign")
            }
        }

        ObjectModel {
            id: footerLeftButtonsModel

            // Navigation-style left footer content.
            StatusBackButton {
                onClicked: {
                    logs.logEvent("StatusAdaptiveDialog::backClicked")
                    dialog.openInternalPopup()
                }
            }
        }

        ObjectModel {
            id: footerLeftInfoModel

            // Compact informational left footer content.
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                StatusBaseText {
                    font.pixelSize: Theme.tertiaryTextFontSize
                    color: Theme.palette.directColor5
                    text: qsTr("Est. time")
                }
                StatusBaseText {
                    font.pixelSize: Theme.primaryTextFontSize
                    font.weight: Font.Medium
                    color: Theme.palette.directColor1
                    text: qsTr("~3 mins")
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                StatusBaseText {
                    font.pixelSize: Theme.tertiaryTextFontSize
                    color: Theme.palette.directColor5
                    text: qsTr("Max fees")
                }
                StatusBaseText {
                    font.pixelSize: Theme.primaryTextFontSize
                    font.weight: Font.Medium
                    color: Theme.palette.directColor1
                    text: qsTr("$0.42")
                }
            }
        }

        // Right buttons vary by mode: "cancel-done" includes both, others just Done.
        ObjectModel {
            id: footerRightButtonsCancelDoneModel

            StatusFlatButton {
                text: qsTr("Cancel")
                onClicked: dialog.close()
            }

            StatusButton {
                text: qsTr("Done")
                onClicked: {
                    logs.logEvent("StatusAdaptiveDialog::doneClicked")
                    dialog.close()
                }
            }
        }

        ObjectModel {
            id: footerRightButtonsDoneModel

            StatusButton {
                text: qsTr("Done")
                onClicked: {
                    logs.logEvent("StatusAdaptiveDialog::doneClicked")
                    dialog.close()
                }
            }
        }

        ObjectModel {
            id: errorTagsOneModel

            RouterErrorTag {
                errorTitle: qsTr("Insufficient funds for send transaction")
                buttonText: qsTr("Add ETH")
                onButtonClicked: logs.logEvent("StatusAdaptiveDialog::errorTagButtonClicked")
            }
        }

        ObjectModel {
            id: errorTagsTwoModel

            RouterErrorTag {
                errorTitle: qsTr("Insufficient funds for send transaction")
                buttonText: qsTr("Add ETH")
                onButtonClicked: logs.logEvent("StatusAdaptiveDialog::errorTagButtonClicked")
            }

            RouterErrorTag {
                errorTitle: qsTr("Not enough ETH to pay gas fees")
                errorDetails: qsTr("This route requires more ETH than available in your wallet. Try a different route or add more ETH.")
                buttonText: qsTr("Add ETH")
                expandable: true
                onButtonClicked: logs.logEvent("StatusAdaptiveDialog::errorTagButtonClicked")
            }
        }

        Component {
            id: internalPopupComponent

            StatusAdaptiveDialog {
                id: internalDialog

                title: qsTr("Internal dialog")
                subtitle: qsTr("This dialog is hosted inside the parent surface")
                closeOnOverlayClick: false
                escapeKeyCloses: true
                contentComponent: Component {
                    StatusBaseText {
                        wrapMode: Text.WordWrap
                        color: Theme.palette.directColor5
                        text: qsTr("Lazy StatusAdaptiveDialog created and managed by the parent dialog's internal popup layer.")
                    }
                }
                footerRightButtons: ObjectModel {
                    StatusButton {
                        text: qsTr("Close")
                        onClicked: {
                            logs.logEvent("StatusAdaptiveDialog::internalPopupCloseClicked")
                            dialog.closeInternalPopup()
                        }
                    }
                }
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.preferredWidth: 320
        SplitView.fillHeight: true

        logsView.logText: logs.logText

        ColumnLayout {
            Layout.fillWidth: true

            Label {
                text: "Header"
                font.bold: true
            }

            ComboBox {
                id: headerMode
                Layout.fillWidth: true
                textRole: "text"
                valueRole: "value"
                model: [
                    {
                        text: "None",
                        value: "none"
                    },
                    {
                        text: "Title",
                        value: "title"
                    },
                    {
                        text: "Title + subtitle",
                        value: "title-subtitle"
                    },
                    {
                        text: "Image + title",
                        value: "image-title"
                    },
                    {
                        text: "Image + title + subtitle",
                        value: "image-title-subtitle"
                    }
                ]
                currentIndex: 2
            }

            ComboBox {
                id: headerActionsMode
                Layout.fillWidth: true
                textRole: "text"
                valueRole: "value"
                model: [
                    {
                        text: "Close",
                        value: "close"
                    },
                    {
                        text: "Info",
                        value: "info"
                    },
                    {
                        text: "Close + info",
                        value: "both"
                    },
                    {
                        text: "Custom",
                        value: "custom"
                    },
                    {
                        text: "Close + custom",
                        value: "close-custom"
                    },
                    {
                        text: "None",
                        value: "none"
                    }
                ]
            }

            Label {
                text: "Footer"
                font.bold: true
                Layout.topMargin: d.controlsSectionSpacing
            }

            ComboBox {
                id: footerButtonsMode
                Layout.fillWidth: true
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: "Cancel + Done",    value: "cancel-done" },
                    { text: "Back + Done",      value: "back-done" },
                    { text: "Back only",        value: "back-only" },
                    { text: "Info + Done",      value: "info-done" },
                    { text: "Done only",        value: "done-only" },
                    { text: "None",             value: "none" }
                ]
            }

            ComboBox {
                id: footerErrorsMode
                Layout.fillWidth: true
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: "No errors",           value: "none" },
                    { text: "1 error",             value: "one" },
                    { text: "2 errors (expandable)", value: "two" }
                ]
            }

            Label {
                text: "Content"
                font.bold: true
                Layout.topMargin: d.controlsSectionSpacing
            }

            ComboBox {
                id: contentMode
                Layout.fillWidth: true
                textRole: "text"
                valueRole: "value"
                model: [
                    {
                        text: "Short content",
                        value: "short"
                    },
                    {
                        text: "Long content",
                        value: "long"
                    }
                ]
            }

            Label {
                text: "Sizing"
                font.bold: true
                Layout.topMargin: d.controlsSectionSpacing
            }

            Label {
                text: "Max width override: " + (customMaxWidth.checked ? Math.round(maxWidthSlider.value) : "off")
            }

            CheckBox {
                id: customMaxWidth
                text: "Custom max width"
            }

            Slider {
                id: maxWidthSlider
                Layout.fillWidth: true
                enabled: customMaxWidth.checked
                from: 360
                to: 720
                stepSize: 20
                value: 560
            }

            CheckBox {
                id: heightCap
                text: "Custom height cap"
            }

            Label {
                text: "Height cap: " + Math.round(heightSlider.value)
            }

            Slider {
                id: heightSlider
                Layout.fillWidth: true
                enabled: heightCap.checked
                from: 220
                to: 640
                stepSize: 20
                value: 420
            }

            Label {
                text: "Mode: " + (d.dialogBottomSheet ? "bottom sheet" : "centered")
            }

            Label {
                text: "Behavior"
                font.bold: true
                Layout.topMargin: d.controlsSectionSpacing
            }

            CheckBox {
                id: closeOnOverlay
                text: "Close on overlay click"
                checked: true
            }

            CheckBox {
                id: escapeCloses
                text: "Escape closes"
                checked: true
            }
        }
    }
}
