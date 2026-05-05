import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils
import shared
import shared.views
import shared.status
import shared.views.chat

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls as StatusQ

SettingsContentBase {
    id: root

    required property int theme // ThemeUtils.Style.xxx
    required property int fontSize // ThemeUtils.FontSize.xxx
    required property int paddingFactor // ThemeUtils.PaddingFactor.xxx

    signal themeChangeRequested(int theme)
    signal fontSizeChangeRequested(int fontSize)
    signal paddingFactorChangeRequested(int paddingFactor)

    content: ColumnLayout {
        id: appearanceContainer

        width: root.contentWidth - 2 * Theme.padding
        spacing: Theme.padding

        Rectangle {
            id: preview

            Layout.preferredHeight: placeholderMessage.implicitHeight +
                                    placeholderMessage.anchors.leftMargin +
                                    placeholderMessage.anchors.rightMargin
            Layout.fillWidth: true

            radius: Theme.radius
            border.color: Theme.palette.border
            color: StatusColors.transparent

            MessageView {
                id: placeholderMessage
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.padding

                isMessage: true
                shouldRepeatHeader: true
                messageTimestamp: Date.now()
                senderDisplayName: "vitalik.eth"
                senderIcon: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAYAAAAeP4ixAAAAb0lEQVR4Ae3UQQqAIBRF0Wj9ba9Bq6l5JBQqfn/ngDMH3YS3AAB/tO3H+XRG3b9bR/+gVoREI2RapVXpfd5+X5oXERKNkHS+rk3tOpWkeREh0QiZVu91ql2zNC8iJBoh0yqtSqt1slpCghICANDPBc0ESPh0bHkHAAAAAElFTkSuQmCC"
                messageText: qsTr("Blockchains will drop search costs, causing a kind of decomposition that allows you to have markets of entities that are horizontally segregated and vertically segregated.")
                messageContentType: Constants.messageContentType.messageType
                placeholderMessage: true
            }
        }

        StatusSectionHeadline {
            id: sectionHeadlineFontSize
            text: qsTr("Text size")
            Layout.topMargin: 2 * Theme.padding
        }

        StatusQ.StatusLabeledSlider {
            id: fontSizeSlider
            Layout.fillWidth: true
            Layout.leftMargin: Theme.smallPadding
            Layout.rightMargin: Layout.leftMargin

            textRole: "name"
            valueRole: "value"
            model: ListModel {
                ListElement { name: qsTr("XS"); value: ThemeUtils.FontSize.FontSizeXS }
                ListElement { name: qsTr("S"); value: ThemeUtils.FontSize.FontSizeS }
                ListElement { name: qsTr("M"); value: ThemeUtils.FontSize.FontSizeM }
                ListElement { name: qsTr("L"); value: ThemeUtils.FontSize.FontSizeL }
                ListElement { name: qsTr("XL"); value: ThemeUtils.FontSize.FontSizeXL }
                ListElement { name: qsTr("XXL"); value: ThemeUtils.FontSize.FontSizeXXL }
            }

            value: root.fontSize

            onMoved: root.fontSizeChangeRequested(value)
        }

        StatusSectionHeadline {
            text: qsTr("Layout Spacing")
            Layout.topMargin: 2 * Theme.padding
        }

        StatusBaseText {
            Layout.fillWidth: true
            text: qsTr("Adjust how compact or spacious the layout looks")
            wrapMode: Text.Wrap
        }

        StatusQ.StatusLabeledSlider {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.smallPadding
            Layout.rightMargin: Layout.leftMargin

            textRole: "name"
            valueRole: "value"
            model: ListModel {
                ListElement { name: qsTr("XXS"); value: ThemeUtils.PaddingFactor.PaddingXXS }
                ListElement { name: qsTr("XS"); value: ThemeUtils.PaddingFactor.PaddingXS }
                ListElement { name: qsTr("S"); value: ThemeUtils.PaddingFactor.PaddingS }
                ListElement { name: qsTr("M"); value: ThemeUtils.PaddingFactor.PaddingM }
                ListElement { name: qsTr("L"); value: ThemeUtils.PaddingFactor.PaddingL }
            }

            value: root.paddingFactor

            onMoved: root.paddingFactorChangeRequested(value)
        }

        Rectangle {
            Layout.topMargin: Theme.xlPadding
            Layout.preferredHeight: 1
            Layout.fillWidth: true
            color: Theme.palette.separator
        }

        StatusSectionHeadline {
            text: qsTr("Mode")
            Layout.topMargin: Theme.xlPadding
        }

        RowLayout {
            id: modeRow

            Layout.fillWidth: true
            spacing: Theme.halfPadding

            StatusImageRadioButton {
                Layout.fillWidth: true
                image.source: Assets.png("appearance-light")
                control.text: qsTr("Light")
                control.checked: root.theme === ThemeUtils.Style.Light
                control.font.pixelSize: Theme.fontSize(14)
                onRadioCheckedChanged: function(checked) {
                    if (checked) {
                        root.themeChangeRequested(ThemeUtils.Style.Light)
                    }
                }
            }

            StatusImageRadioButton {
                Layout.fillWidth: true
                image.source: Assets.png("appearance-dark")
                control.text: qsTr("Dark")
                control.checked: root.theme === ThemeUtils.Style.Dark
                control.font.pixelSize: Theme.fontSize(14)
                onRadioCheckedChanged: function(checked) {
                    if (checked) {
                        root.themeChangeRequested(ThemeUtils.Style.Dark)
                    }
                }
            }

            StatusImageRadioButton {
                Layout.fillWidth: true
                image.source: Assets.png("appearance-system")
                control.text: qsTr("System")
                control.checked: root.theme === ThemeUtils.Style.System
                control.font.pixelSize: Theme.fontSize(14)
                onRadioCheckedChanged: function(checked) {
                    if (checked) {
                        root.themeChangeRequested(ThemeUtils.Style.System)
                    }
                }
            }
        }
    }
}
