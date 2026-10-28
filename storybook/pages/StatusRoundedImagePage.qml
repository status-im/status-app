import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components

import Models
import Storybook

SplitView {
    id: root

    orientation: Qt.Horizontal

    Rectangle {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        color: darkBackgroundCheckBox.checked ? "#1b2032" : "#f5f6f8"

        StatusRoundedImage {
            id: roundedImage

            anchors.centerIn: parent

            width: sizeSlider.value
            height: aspectSlider.value * sizeSlider.value

            radius: circleCheckBox.checked ? Math.min(width, height) / 2 : radiusSlider.value
            topLeftRadius: cornersCheckBox.checked ? topLeftSlider.value : radius
            topRightRadius: cornersCheckBox.checked ? topRightSlider.value : radius
            bottomRightRadius: cornersCheckBox.checked ? bottomRightSlider.value : radius
            bottomLeftRadius: cornersCheckBox.checked ? bottomLeftSlider.value : radius

            color: backgroundComboBox.currentValue
            border.width: borderWidthSlider.value
            border.color: borderColorComboBox.currentValue

            showLoadingIndicator: loadingIndicatorCheckBox.checked
            isLoading: simulateLoadingCheckBox.checked || image.status === Image.Loading

            image.source: sourceComboBox.currentValue
            image.fillMode: fillModeComboBox.currentValue
            image.asynchronous: true

            // a badge-sized circle cut out at the bottom-right
            image.cutoutRadius: cutoutCheckBox.checked ? image.width * 0.22 : 0
            image.cutoutCenter: Qt.point(image.width * 0.85, image.height * 0.85)
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 380
        SplitView.fillHeight: true

        ScrollView {
            anchors.fill: parent
            contentWidth: availableWidth

            ColumnLayout {
                width: parent.width

                Label { text: "Source" }
                ComboBox {
                    id: sourceComboBox

                    Layout.fillWidth: true
                    textRole: "text"
                    valueRole: "value"
                    model: [
                        { text: "Photo, 1280 × 720", value: Qt.resolvedUrl("../testData/image_example_large.jpg") },
                        { text: "Wide image, 320 × 180", value: Qt.resolvedUrl("../testData/image_example.png") },
                        { text: "Token logo (transparent)", value: ModelsData.assets.eth },
                        { text: "Missing file (error)", value: "file:///does/not/exist.png" },
                        { text: "None", value: "" }
                    ]
                }

                Label { text: "Fill mode (StatusImage's default: PreserveAspectFit)" }
                ComboBox {
                    id: fillModeComboBox

                    Layout.fillWidth: true
                    textRole: "text"
                    valueRole: "value"
                    model: [
                        { text: "PreserveAspectFit", value: Image.PreserveAspectFit },
                        { text: "PreserveAspectCrop", value: Image.PreserveAspectCrop },
                        { text: "Stretch", value: Image.Stretch },
                        { text: "Tile", value: Image.Tile },
                        { text: "Pad", value: Image.Pad }
                    ]
                }

                Label { text: `Width: ${sizeSlider.value} px` }
                Slider {
                    id: sizeSlider

                    Layout.fillWidth: true
                    from: 16
                    to: 320
                    stepSize: 1
                    value: 120
                }

                Label { text: `Height / width: ${aspectSlider.value.toFixed(2)}` }
                Slider {
                    id: aspectSlider

                    Layout.fillWidth: true
                    from: 0.25
                    to: 2
                    stepSize: 0.05
                    value: 1
                }

                CheckBox {
                    id: circleCheckBox

                    text: "Circle (radius: half the size, the default)"
                    checked: true
                }

                Label {
                    text: `Radius: ${radiusSlider.value} px`
                    enabled: !circleCheckBox.checked
                }
                Slider {
                    id: radiusSlider

                    Layout.fillWidth: true
                    enabled: !circleCheckBox.checked
                    from: 0
                    to: 160
                    stepSize: 1
                    value: 16
                }

                CheckBox {
                    id: cornersCheckBox

                    text: "Per-corner radii"
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    enabled: cornersCheckBox.checked

                    Label { text: `Top left: ${topLeftSlider.value}` }
                    Slider { id: topLeftSlider; Layout.fillWidth: true; from: 0; to: 160; stepSize: 1; value: 32 }
                    Label { text: `Top right: ${topRightSlider.value}` }
                    Slider { id: topRightSlider; Layout.fillWidth: true; from: 0; to: 160; stepSize: 1; value: 32 }
                    Label { text: `Bottom right: ${bottomRightSlider.value}` }
                    Slider { id: bottomRightSlider; Layout.fillWidth: true; from: 0; to: 160; stepSize: 1; value: 32 }
                    Label { text: `Bottom left: ${bottomLeftSlider.value}` }
                    Slider { id: bottomLeftSlider; Layout.fillWidth: true; from: 0; to: 160; stepSize: 1; value: 4 }
                }

                Label { text: "Background color" }
                ComboBox {
                    id: backgroundComboBox

                    Layout.fillWidth: true
                    textRole: "text"
                    valueRole: "value"
                    model: [
                        { text: "Transparent (default)", value: "transparent" },
                        { text: "Light grey", value: "#dde1e9" },
                        { text: "Blue", value: "#4360df" }
                    ]
                }

                Label { text: `Border width: ${borderWidthSlider.value} px` }
                Slider {
                    id: borderWidthSlider

                    Layout.fillWidth: true
                    from: 0
                    to: 12
                    stepSize: 1
                    value: 0
                }

                Label { text: "Border color" }
                ComboBox {
                    id: borderColorComboBox

                    Layout.fillWidth: true
                    textRole: "text"
                    valueRole: "value"
                    model: [
                        { text: "Blue", value: "#4360df" },
                        { text: "White", value: "white" },
                        { text: "Black", value: "black" }
                    ]
                }

                CheckBox {
                    id: cutoutCheckBox

                    text: "Cut-out for a badge (image.cutoutRadius)"
                }

                CheckBox {
                    id: loadingIndicatorCheckBox

                    text: "Show loading indicator"
                    checked: true
                }

                CheckBox {
                    id: simulateLoadingCheckBox

                    text: "Simulate loading (isLoading)"
                }

                CheckBox {
                    id: darkBackgroundCheckBox

                    text: "Dark page background"
                }

                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    wrapMode: Text.Wrap
                    text: {
                        const states = ["Null", "Ready", "Loading", "Error"]
                        return `image.status: ${states[roundedImage.image.status]}`
                            + `\nisLoading: ${roundedImage.isLoading}, isError: ${roundedImage.isError}`
                            + `\npainted: ${Math.round(roundedImage.image.paintedWidth)}`
                            + ` × ${Math.round(roundedImage.image.paintedHeight)}`
                    }
                }
            }
        }
    }
}

// category: Components
// status: good
