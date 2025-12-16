import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core.Theme

Control {
    id: root

    property int style // Theme.Style
    property int fontSizeOffset
    property real themePadding

    signal styleRequested(int style) // Theme.Style

    signal paddingRequested(int padding)
    signal paddingFactorRequested(int paddingFactor) // ThemeUtils.PaddingFactor

    signal fontSizeOffsetRequested(int fontSizeOffset)
    signal fontSizeRequested(int fontSize) // ThemeUtils.FontSize

    signal resetRequested

    contentItem: ColumnLayout {
        RowLayout {

            Label {
                text: "Theme:"
            }

            Flow {
                Layout.fillWidth: true
                spacing: 2

                RoundButton {
                    text: "Light"
                    checked: root.style === Theme.Style.Light

                    onClicked: root.styleRequested(Theme.Style.Light)
                }

                RoundButton {
                    text: "Dark"
                    checked: root.style === Theme.Style.Dark

                    onClicked: root.styleRequested(Theme.Style.Dark)
                }
            }
        }

        ToolSeparator {
            orientation: Qt.Horizontal
            Layout.fillWidth: true
        }

        RowLayout {
            Label {
                text: "Padding:"
            }

            Slider {
                id: paddingSlider

                Layout.fillWidth: true

                from: 0
                to: 40
                stepSize: 1

                value: root.themePadding

                onValueChanged: {
                    if (value !== root.themePadding)
                        root.paddingRequested(value)
                }
            }
            Label {
                text: root.themePadding
            }
        }

        Flow {
            Layout.fillWidth: true

            spacing: 2

            Repeater {
                model: [
                    "XXS", "XS", "S", "M", "L"
                ]

                RoundButton {
                    required property string modelData

                    checked: root.themePadding === Theme.defaultPadding * ThemeUtils["paddingFactor" + modelData]

                    text: modelData

                    onClicked: root.paddingFactorRequested(
                                   ThemeUtils["Padding" + modelData])
                }
            }
        }

        ToolSeparator {
            orientation: Qt.Horizontal
            Layout.fillWidth: true
        }

        RowLayout {
            Label {
                text: "Font size offset:"
            }

            Slider {
                id: fontSizeOffsetSlider

                Layout.fillWidth: true

                from: -4
                to: 6
                stepSize: 1

                value: root.fontSizeOffset


                onValueChanged: {
                    if (root.fontSizeOffset !== value)
                        root.fontSizeOffsetRequested(value)
                }
            }

            Label {
                text: root.fontSizeOffset
            }
        }

        Flow {
            spacing: 2

            Layout.fillWidth: true

            Repeater {
                model: [
                    "XS", "S", "M", "L", "XL", "XXL"
                ]

                RoundButton {
                    required property string modelData

                    checked: root.fontSizeOffset ===
                             ThemeUtils["fontSizeOffset" + modelData]

                    text: modelData

                    onClicked: root.fontSizeRequested(ThemeUtils["FontSize" + modelData])
                }
            }
        }

        ToolSeparator {
            orientation: Qt.Horizontal
            Layout.fillWidth: true
        }

        RoundButton {
            Layout.alignment: Qt.AlignHCenter
            text: "Reset"

            onClicked: root.resetRequested()
        }
    }
}
