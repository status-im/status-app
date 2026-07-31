pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Controls.Validators
import StatusQ.Popups.Dialog

SplitView {
    id: root

    orientation: Qt.Horizontal

    Logs {
        id: logs
    }

    QtObject {
        id: d

        readonly property var window: root.Window.window
        readonly property bool dialogBottomSheet: !!window && stackDialog.width === window.width
                                                    && stackDialog.y > window.height / 2
        readonly property real controlsSectionSpacing: Math.max(Theme.halfPadding, 8)
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
                    text: qsTr("Open stack dialog")
                    onClicked: stackDialog.open()
                }
            }
        }

        StatusAdaptiveStackDialog {
            id: stackDialog

            defaultTitle: qsTr("Stack dialog")
            maximumWidthOverride: customMaxWidth.checked && !d.dialogBottomSheet ? maxWidthSlider.value : 0
            maximumHeightOverride: customHeightCap.checked ? heightCapSlider.value : 0
            closeOnOverlayClick: closeOnOverlay.checked
            escapeKeyCloses: escapeCloses.checked
            subHeaderItem: showSubHeader.checked ? subHeaderComponent : null
            subHeaderPadding: Theme.padding
            showStackFooter: showFooter.checked
            initialItem: introStepComponent

            onAboutToShow: {
                replace(null)
                if (resetOnOpen.checked)
                    resetStack(StackView.Immediate)
                logs.logEvent("StatusAdaptiveStackDialog::aboutToShow")
            }

            Component {
                id: introStepComponent

                ColumnLayout {
                    spacing: Theme.halfPadding

                    readonly property string title: qsTr("Choose account")
                    readonly property string nextButtonObjectName: "storybookStackNextButton"
                    readonly property string nextButtonText: qsTr("Continue")
                    readonly property bool canGoNext: accountRadio.checked || keycardRadio.checked
                    readonly property var nextAction: function() {
                        logs.logEvent("StatusAdaptiveStackDialog::introNext")
                        stackDialog.stack.push(detailsStepComponent)
                    }

                    StatusBaseText {
                        Layout.fillWidth: true
                        Layout.bottomMargin: Theme.halfPadding
                        wrapMode: Text.WordWrap
                        color: Theme.palette.directColor5
                        text: qsTr("First stack step. The primary footer button is disabled until a radio option is selected.")
                    }

                    StatusRadioButton {
                        id: accountRadio
                        text: qsTr("Regular account")
                    }

                    StatusRadioButton {
                        id: keycardRadio
                        text: qsTr("Keycard account")
                    }
                }
            }

            Component {
                id: detailsStepComponent

                ColumnLayout {
                    spacing: Theme.halfPadding

                    readonly property string title: qsTr("Fill details")
                    readonly property string nextButtonText: qsTr("Review")
                    readonly property bool canGoNext: nameInput.valid
                    readonly property var nextAction: function() {
                        logs.logEvent("StatusAdaptiveStackDialog::detailsNext")
                        stackDialog.stack.push(reviewStepComponent)
                    }

                    StatusInput {
                        id: nameInput

                        Layout.fillWidth: true
                        label: qsTr("Display name")
                        placeholderText: qsTr("Name this flow")
                        validators: [
                            StatusMinLengthValidator {
                                minLength: 1
                                errorMessage: qsTr("Enter a display name")
                            }
                        ]
                    }

                    StatusBaseText {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: Theme.palette.baseColor1
                        text: qsTr("Use the footer back button to pop this StackView step.")
                    }
                }
            }

            Component {
                id: reviewStepComponent

                ColumnLayout {
                    spacing: Theme.halfPadding

                    readonly property string title: qsTr("Review")
                    readonly property string nextButtonText: qsTr("Show replace panel")
                    readonly property var nextAction: function() {
                        logs.logEvent("StatusAdaptiveStackDialog::reviewNext")
                        stackDialog.replace(replaceStepComponent)
                    }

                    StatusBaseText {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: Theme.palette.directColor5
                        text: qsTr("Final stack step. Next swaps the content with replaceItem while keeping the dialog shell.")
                    }
                }
            }

            Component {
                id: replaceStepComponent

                ColumnLayout {
                    spacing: Theme.halfPadding

                    readonly property string title: qsTr("Replace panel")

                    StatusLoadingIndicator {
                        Layout.alignment: Qt.AlignHCenter
                        width: 48
                        height: 48
                    }

                    StatusBaseText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        color: Theme.palette.directColor5
                        text: qsTr("Back clears replaceItem and returns to the review step.")
                    }
                }
            }

            Component {
                id: subHeaderComponent

                StatusBaseText {
                    width: parent ? parent.width : implicitWidth
                    wrapMode: Text.WordWrap
                    color: Theme.palette.baseColor1
                    text: qsTr("Persistent sub-header content")
                }
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.preferredWidth: 300
        SplitView.fillHeight: true

        logsView.logText: logs.logText

        ScrollView {
            id: controlsScrollView

            anchors.fill: parent
            clip: true
            contentWidth: availableWidth

            ColumnLayout {
                width: controlsScrollView.availableWidth

                Label {
                    text: qsTr("Stack")
                    font.bold: true
                }

                CheckBox {
                    id: showFooter
                    text: qsTr("Show footer")
                    checked: true
                }

                CheckBox {
                    id: showSubHeader
                    text: qsTr("Show sub-header")
                }

                CheckBox {
                    id: resetOnOpen
                    text: qsTr("Reset on open")
                    checked: true
                }

                Label {
                    text: qsTr("Current index: %1").arg(stackDialog.currentIndex)
                }

                Label {
                    text: qsTr("Depth: %1").arg(stackDialog.depth)
                }

                RowLayout {
                    Layout.fillWidth: true

                    Button {
                        Layout.fillWidth: true
                        text: qsTr("Back")
                        enabled: stackDialog.opened && stackDialog.showStackBackButton
                        onClicked: stackDialog.back()
                    }

                    Button {
                        Layout.fillWidth: true
                        text: qsTr("Reset")
                        enabled: stackDialog.opened
                        onClicked: {
                            stackDialog.replace(null)
                            stackDialog.resetStack(StackView.Immediate)
                        }
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: qsTr("Show replace panel")
                    enabled: stackDialog.opened
                    onClicked: stackDialog.replace(replaceStepComponent)
                }

                Label {
                    text: qsTr("Sizing")
                    font.bold: true
                    Layout.topMargin: d.controlsSectionSpacing
                }

                CheckBox {
                    id: customMaxWidth
                    text: qsTr("Custom max width")
                    enabled: !d.dialogBottomSheet
                }

                Label {
                    text: qsTr("Max width: %1").arg(customMaxWidth.checked && !d.dialogBottomSheet
                                                    ? Math.round(maxWidthSlider.value) : qsTr("off"))
                }

                Slider {
                    id: maxWidthSlider
                    Layout.fillWidth: true
                    enabled: customMaxWidth.checked && !d.dialogBottomSheet
                    from: 360
                    to: 720
                    stepSize: 20
                    value: 520
                }

                CheckBox {
                    id: customHeightCap
                    text: qsTr("Custom height cap")
                }

                Label {
                    text: qsTr("Height cap: %1").arg(customHeightCap.checked
                                                     ? Math.round(heightCapSlider.value) : qsTr("off"))
                }

                Slider {
                    id: heightCapSlider
                    Layout.fillWidth: true
                    enabled: customHeightCap.checked
                    from: 220
                    to: 640
                    stepSize: 20
                    value: 420
                }

                Label {
                    text: qsTr("Behavior")
                    font.bold: true
                    Layout.topMargin: d.controlsSectionSpacing
                }

                CheckBox {
                    id: closeOnOverlay
                    text: qsTr("Close on overlay click")
                    checked: true
                }

                CheckBox {
                    id: escapeCloses
                    text: qsTr("Escape closes")
                    checked: true
                }

                Label {
                    text: qsTr("Mode: %1").arg(d.dialogBottomSheet ? qsTr("bottom sheet") : qsTr("centered"))
                }
            }
        }
    }
}

// category: Popups
// status: good
