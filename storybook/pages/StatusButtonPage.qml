import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Controls

import Storybook

SplitView {
    Logs { id: logs }

    ButtonGroup {
        id: rippleOriginButtonGroup
    }

    QtObject {
        id: d
        readonly property var sizesModel: [StatusBaseButton.Size.XSmall, StatusBaseButton.Size.Tiny, StatusBaseButton.Size.Small, StatusBaseButton.Size.Large]
        readonly property real disabledControlOpacity: 0.5

        readonly property string effectiveEmoji: ctrlEmojiEnabled.checked ? ctrlEmoji.text : ""
        readonly property int effectiveTextPosition: ctrlTextPosLeft.checked ? StatusBaseButton.TextPosition.Left
                                                                             : StatusBaseButton.TextPosition.Right
        readonly property int effectiveRippleOrigin: ctrlRippleFollowPointer.checked
                                                     ? StatusRipple.RippleOrigin.Pointer
                                                     : StatusRipple.RippleOrigin.Center
    }

    SplitView {
        orientation: Qt.Horizontal
        SplitView.fillWidth: true

        Pane {
            SplitView.fillWidth: true
            SplitView.fillHeight: true

            GridLayout {
                anchors.centerIn: parent
                rowSpacing: 10
                columnSpacing: 10
                columns: 5

                Label { text: "" }
                Label { text: "XSmall" }
                Label { text: "Tiny" }
                Label { text: "Small" }
                Label { text: "Large" }

                Label {
                    text: "StatusButton"
                    Layout.columnSpan: 5
                    font.bold: true
                }

                Label { text: "Text only:" }
                Repeater {
                    model: d.sizesModel
                    delegate: StatusButton {
                        Layout.preferredWidth: ctrlWidth.value || implicitWidth
                        size: modelData
                        text: ctrlText.text
                        asset.emoji: d.effectiveEmoji
                        tooltip.text: ctrlTooltip.text
                        textPosition: d.effectiveTextPosition
                        type: ctrlType.currentIndex
                        loading: ctrlLoading.checked
                        loadingWithText: ctrlLoadingWithText.checked
                        enabled: ctrlEnabled.checked
                        interactive: ctrlInteractive.checked
                        rippleEnabled: ctrlRipple.checked
                        rippleOrigin: d.effectiveRippleOrigin
                        scaleOnPressEnabled: ctrlScaleOnPress.checked
                        textFillWidth: ctrlFillWidth.checked
                        isOutline: ctrlIsOutline.checked
                    }
                }

                Label { text: "Icon only:" }
                Repeater {
                    model: d.sizesModel
                    delegate: StatusButton {
                        Layout.preferredWidth: ctrlWidth.value || implicitWidth
                        size: modelData
                        icon.name: ctrlIconName.text
                        asset.emoji: d.effectiveEmoji
                        tooltip.text: ctrlTooltip.text
                        textPosition: d.effectiveTextPosition
                        type: ctrlType.currentIndex
                        loading: ctrlLoading.checked
                        loadingWithText: ctrlLoadingWithText.checked
                        enabled: ctrlEnabled.checked
                        interactive: ctrlInteractive.checked
                        rippleEnabled: ctrlRipple.checked
                        rippleOrigin: d.effectiveRippleOrigin
                        scaleOnPressEnabled: ctrlScaleOnPress.checked
                        textFillWidth: ctrlFillWidth.checked
                        isOutline: ctrlIsOutline.checked
                    }
                }

                Label { text: "Text + icon:" }
                Repeater {
                    model: d.sizesModel
                    delegate: StatusButton {
                        Layout.preferredWidth: ctrlWidth.value || implicitWidth
                        size: modelData
                        text: ctrlText.text
                        icon.name: ctrlIconName.text
                        asset.emoji: d.effectiveEmoji
                        tooltip.text: ctrlTooltip.text
                        textPosition: d.effectiveTextPosition
                        type: ctrlType.currentIndex
                        loading: ctrlLoading.checked
                        loadingWithText: ctrlLoadingWithText.checked
                        enabled: ctrlEnabled.checked
                        interactive: ctrlInteractive.checked
                        rippleEnabled: ctrlRipple.checked
                        rippleOrigin: d.effectiveRippleOrigin
                        scaleOnPressEnabled: ctrlScaleOnPress.checked
                        textFillWidth: ctrlFillWidth.checked
                        isOutline: ctrlIsOutline.checked
                    }
                }

                Label { text: "Round icon:" }
                Repeater {
                    model: d.sizesModel
                    delegate: StatusButton {
                        Layout.preferredWidth: ctrlWidth.value || implicitWidth
                        Layout.preferredHeight: width
                        size: modelData
                        icon.name: ctrlIconName.text
                        asset.emoji: d.effectiveEmoji
                        tooltip.text: ctrlTooltip.text
                        textPosition: d.effectiveTextPosition
                        type: ctrlType.currentIndex
                        loading: ctrlLoading.checked
                        loadingWithText: ctrlLoadingWithText.checked
                        enabled: ctrlEnabled.checked
                        interactive: ctrlInteractive.checked
                        rippleEnabled: ctrlRipple.checked
                        rippleOrigin: d.effectiveRippleOrigin
                        scaleOnPressEnabled: ctrlScaleOnPress.checked
                        isRoundIcon: true
                        textFillWidth: ctrlFillWidth.checked
                        isOutline: ctrlIsOutline.checked
                    }
                }

                Label {
                    text: "StatusFlatButton"
                    Layout.columnSpan: 5
                    font.bold: true
                }

                Label { text: "Text only:" }
                Repeater {
                    model: d.sizesModel
                    delegate: StatusFlatButton {
                        Layout.preferredWidth: ctrlWidth.value || implicitWidth
                        size: modelData
                        text: ctrlText.text
                        asset.emoji: d.effectiveEmoji
                        tooltip.text: ctrlTooltip.text
                        textPosition: d.effectiveTextPosition
                        type: ctrlType.currentIndex
                        loading: ctrlLoading.checked
                        loadingWithText: ctrlLoadingWithText.checked
                        enabled: ctrlEnabled.checked
                        interactive: ctrlInteractive.checked
                        rippleEnabled: ctrlRipple.checked
                        rippleOrigin: d.effectiveRippleOrigin
                        scaleOnPressEnabled: ctrlScaleOnPress.checked
                        textFillWidth: ctrlFillWidth.checked
                    }
                }

                Label { text: "Icon only:" }
                Repeater {
                    model: d.sizesModel
                    delegate: StatusFlatButton {
                        Layout.preferredWidth: ctrlWidth.value || implicitWidth
                        size: modelData
                        icon.name: ctrlIconName.text
                        asset.emoji: d.effectiveEmoji
                        tooltip.text: ctrlTooltip.text
                        textPosition: d.effectiveTextPosition
                        type: ctrlType.currentIndex
                        loading: ctrlLoading.checked
                        loadingWithText: ctrlLoadingWithText.checked
                        enabled: ctrlEnabled.checked
                        interactive: ctrlInteractive.checked
                        rippleEnabled: ctrlRipple.checked
                        rippleOrigin: d.effectiveRippleOrigin
                        scaleOnPressEnabled: ctrlScaleOnPress.checked
                        textFillWidth: ctrlFillWidth.checked
                    }
                }

                Label { text: "Text + icon:" }
                Repeater {
                    model: d.sizesModel
                    delegate: StatusFlatButton {
                        Layout.preferredWidth: ctrlWidth.value || implicitWidth
                        size: modelData
                        text: ctrlText.text
                        icon.name: ctrlIconName.text
                        asset.emoji: d.effectiveEmoji
                        tooltip.text: ctrlTooltip.text
                        textPosition: d.effectiveTextPosition
                        type: ctrlType.currentIndex
                        loading: ctrlLoading.checked
                        loadingWithText: ctrlLoadingWithText.checked
                        enabled: ctrlEnabled.checked
                        interactive: ctrlInteractive.checked
                        rippleEnabled: ctrlRipple.checked
                        rippleOrigin: d.effectiveRippleOrigin
                        scaleOnPressEnabled: ctrlScaleOnPress.checked
                        textFillWidth: ctrlFillWidth.checked
                    }
                }

                Label { text: "Round icon:" }
                Repeater {
                    model: d.sizesModel
                    delegate: StatusFlatButton {
                        Layout.preferredWidth: ctrlWidth.value || implicitWidth
                        Layout.preferredHeight: width
                        size: modelData
                        icon.name: ctrlIconName.text
                        asset.emoji: d.effectiveEmoji
                        tooltip.text: ctrlTooltip.text
                        textPosition: d.effectiveTextPosition
                        type: ctrlType.currentIndex
                        loading: ctrlLoading.checked
                        loadingWithText: ctrlLoadingWithText.checked
                        enabled: ctrlEnabled.checked
                        interactive: ctrlInteractive.checked
                        rippleEnabled: ctrlRipple.checked
                        rippleOrigin: d.effectiveRippleOrigin
                        scaleOnPressEnabled: ctrlScaleOnPress.checked
                        isRoundIcon: true
                        textFillWidth: ctrlFillWidth.checked
                    }
                }
            }
        }

        LogsAndControlsPanel {
            id: logsAndControlsPanel

            SplitView.minimumWidth: 300
            SplitView.preferredWidth: 400

            logsView.logText: logs.logText

            ColumnLayout {
                width: parent.width
                RowLayout {
                    Label { text: "Text:" }
                    TextField {
                        id: ctrlText
                        placeholderText: "Button text"
                        text: "Foobar"
                    }
                    // enum StatusBaseButton.TextPosition.xxx
                    RadioButton {
                        id: ctrlTextPosLeft
                        text: "left"
                    }
                    RadioButton {
                        id: ctrlTextPosRight
                        text: "right"
                        checked: true
                    }
                }
                RowLayout {
                    Label { text: "Icon name:" }
                    TextField {
                        id: ctrlIconName
                        placeholderText: "Icon name"
                        text: "gif"
                    }
                }
                RowLayout {
                    Label { text: "Emoji:" }
                    TextField {
                        id: ctrlEmoji
                        text: "💩"
                    }
                    CheckBox {
                        id: ctrlEmojiEnabled
                        text: "enabled"
                    }
                }
                RowLayout {
                    Label { text: "Tooltip:" }
                    TextField {
                        id: ctrlTooltip
                        placeholderText: "Tooltip"
                        text: "Sample tooltip"
                    }
                }
                RowLayout {
                    Label { text: "Type:" }
                    ComboBox {
                        id: ctrlType
                        model: ["Normal", "Danger", "Primary", "Warning", "Success"] // enum StatusBaseButton.Type.xxx
                    }
                    CheckBox {
                        id: ctrlIsOutline
                        text: "isOutline"
                    }
                }
                RowLayout {
                    Label { text: "Width:" }
                    SpinBox {
                        id: ctrlWidth
                        from: 0
                        to: 280
                        value: 0 // 0 == implicitWidth
                        stepSize: 10
                        textFromValue: function(value, locale) { return value === 0 ? "Implicit" : value }
                    }
                    CheckBox {
                        id: ctrlFillWidth
                        text: "Fill width"
                    }
                }
                Switch {
                    id: ctrlLoading
                    text: "Loading"
                }
                Switch {
                    id: ctrlLoadingWithText
                    text: "Loading with text"
                }
                Switch {
                    id: ctrlInteractive
                    text: "Interactive"
                    checked: true
                }
                Switch {
                    id: ctrlEnabled
                    text: "Enabled"
                    checked: true
                }
                Label {
                    Layout.topMargin: Theme.defaultPadding
                    text: "Animation on tap"
                    font.weight: Font.Bold
                }
                CheckBox {
                    id: ctrlRipple
                    Layout.leftMargin: Theme.defaultPadding
                    text: "Ripple"
                    checked: true
                }
                RowLayout {
                    Layout.leftMargin: Theme.defaultBigPadding
                    enabled: ctrlRipple.checked
                    opacity: enabled ? 1 : d.disabledControlOpacity
                    RadioButton {
                        id: ctrlRippleFollowPointer
                        ButtonGroup.group: rippleOriginButtonGroup
                        text: "Follow pointer"
                        checked: true
                    }
                    RadioButton {
                        id: ctrlRippleCentered
                        ButtonGroup.group: rippleOriginButtonGroup
                        text: "Centered"
                    }
                }
                CheckBox {
                    id: ctrlScaleOnPress
                    Layout.leftMargin: Theme.defaultPadding
                    text: "Scale down"
                    checked: true
                }
            }
        }
    }
}

// category: Controls
// status: good
// https://www.figma.com/design/MtAO3a7HnEH5xjCDVNilS7/%F0%9F%8E%A8-Design-System-%E2%8E%9C-Desktop?node-id=1029-5905&m=dev
// https://www.figma.com/design/MtAO3a7HnEH5xjCDVNilS7/%F0%9F%8E%A8-Design-System-%E2%8E%9C-Desktop?node-id=1029-5906&m=dev
// https://www.figma.com/design/MtAO3a7HnEH5xjCDVNilS7/%F0%9F%8E%A8-Design-System-%E2%8E%9C-Desktop?node-id=1029-5612&m=dev
// https://www.figma.com/design/MtAO3a7HnEH5xjCDVNilS7/%F0%9F%8E%A8-Design-System-%E2%8E%9C-Desktop?node-id=1029-5613&m=dev
// https://www.figma.com/design/MtAO3a7HnEH5xjCDVNilS7/%F0%9F%8E%A8-Design-System-%E2%8E%9C-Desktop?node-id=1029-4920&m=dev
// https://www.figma.com/design/MtAO3a7HnEH5xjCDVNilS7/%F0%9F%8E%A8-Design-System-%E2%8E%9C-Desktop?node-id=1029-4921&m=dev
// https://www.figma.com/design/MtAO3a7HnEH5xjCDVNilS7/%F0%9F%8E%A8-Design-System-%E2%8E%9C-Desktop?node-id=1029-5328&m=dev
// https://www.figma.com/design/MtAO3a7HnEH5xjCDVNilS7/%F0%9F%8E%A8-Design-System-%E2%8E%9C-Desktop?node-id=1029-5329&m=dev
