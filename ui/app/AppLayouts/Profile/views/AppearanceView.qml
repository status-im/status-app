import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils
import shared.panels
import shared.status

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Backpressure

SettingsContentBase {
    id: root

    required property int theme // ThemeUtils.Style.xxx
    property string uiScaleFile: StandardPaths.writableLocation(StandardPaths.AppLocalDataLocation) + "/ui-scale"

    signal themeChangeRequested(int theme)
    signal restartRequested

    QtObject {
        id: d
        readonly property bool portraitMode: root.width <= root.contentWidth

        property bool dirty

        property real windowDpr: root.Window.window?.screen.devicePixelRatio ?? root.Screen.devicePixelRatio // current DPR, based on the Screen where the Window currently is
        property real nativeWindowDpr: SystemUtils.nativeDpr(root.Window.window) // baseline/native DPR of the respective Screen

        // refresh values when either the Window changes Screen, or the Screen OS settings have changed
        readonly property var _conn: Connections {
            target: root.Window.window
            function onDevicePixelRatioChanged() {
                Backpressure.debounce(root, 1000, function() {
                    d.windowDpr = root.Window.window?.screen.devicePixelRatio ?? root.Screen.devicePixelRatio
                    d.nativeWindowDpr = SystemUtils.nativeDpr(root.Window.window)
                })()
            }
        }

        readonly property string resultFactor: slider.value !== d.nativeWindowDpr ? Number(slider.value/d.nativeWindowDpr)
                                                                                  : ""

        function resetToDefaults() {
            slider.value = d.nativeWindowDpr
        }

        function reset() {
            slider.value = d.windowDpr
            if (slider.value === d.nativeWindowDpr)
                defaultsToggle.checked = Qt.binding(() => slider.value === d.nativeWindowDpr)
            d.dirty = false
        }
    }

    ignoreDirty: true
    autoscrollWhenDirty: true
    Binding on dirty {
        value: d.dirty
    }
    toast.saveChangesText: qsTr("Restart to apply")
    toast.saveChangesTooltipText: qsTr("Restart Status to apply the new interface zoom level")
    saveChangesButtonEnabled: dirty
    onResetChangesClicked: d.reset()
    onSaveChangesClicked: {
        if (SQUtils.StringUtils.writeTextFile(root.uiScaleFile, d.resultFactor)) {
            d.dirty = false
            root.restartRequested()
        } else {
            console.warn("Writing 'ui-scale' setting failed!")
            d.reset()
        }
    }

    content: ColumnLayout {
        width: root.contentWidth - 2 * Theme.padding
        spacing: Theme.padding

        StatusSectionHeadline { text: qsTr("Mode") }

        RowLayout {
            Layout.fillWidth: true

            StatusImageRadioButton {
                Layout.fillWidth: true
                image.source: d.portraitMode ? Assets.svgImg("appearance-light-small") : Assets.svgImg("appearance-light")
                text: qsTr("Light")
                checked: root.theme === ThemeUtils.Style.Light
                onToggled: {
                    if (checked) {
                        root.themeChangeRequested(ThemeUtils.Style.Light)
                    }
                }
            }

            StatusImageRadioButton {
                Layout.fillWidth: true
                image.source: d.portraitMode ? Assets.svgImg("appearance-system-small") : Assets.svgImg("appearance-system")
                text: qsTr("System")
                checked: root.theme === ThemeUtils.Style.System
                onToggled: {
                    if (checked) {
                        root.themeChangeRequested(ThemeUtils.Style.System)
                    }
                }
            }

            StatusImageRadioButton {
                Layout.fillWidth: true
                image.source: d.portraitMode ? Assets.svgImg("appearance-dark-small") : Assets.svgImg("appearance-dark")
                text: qsTr("Dark")
                checked: root.theme === ThemeUtils.Style.Dark
                onToggled: {
                    if (checked) {
                        root.themeChangeRequested(ThemeUtils.Style.Dark)
                    }
                }
            }
        }

        StatusSectionHeadline {
            Layout.topMargin: Theme.bigPadding
            text: qsTr("Interface zoom")
        }

        StatusBaseText {
            Layout.fillWidth: true
            text: qsTr("Scale the app interface and text")
            elide: Text.ElideRight
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 480
            radius: Theme.radius
            color: Theme.palette.baseColor5

            StatusCommunityCard {
                id: preview
                width: (parent.width / 2) - Theme.padding
                anchors.centerIn: parent

                scale: slider.value/d.nativeWindowDpr
                transformOrigin: Item.Center

                communityId: "community_id"
                name: "Status"
                description: "Private, secure, by design<br>Transact, Message, Browse on your Terms ...integrated into one powerful super app"
                descriptionFontColor: Theme.palette.baseColor1
                members: 42
                activeUsers: members/2
                banner: Assets.png("settings/communities")
                asset.source: Assets.png("status-logo")
                asset.isImage: true
                communityColor: Theme.palette.primaryColor1
                categories: ListModel {
                    id: categoriesModel
                    ListElement { name: "gaming"; emoji: "🎮"; selected: false }
                    ListElement { name: "art"; emoji: "🖼️️"; selected: false }
                    ListElement { name: "crypto"; emoji: "💸"; selected: true }
                    ListElement { name: "markets"; emoji: "💎"; selected: false }
                }
                rigthHeaderComponent: StatusButton {
                    type: StatusBaseButton.Type.Primary
                    size: StatusBaseButton.Size.Tiny
                    icon.name: "communities"
                    text: qsTr("Join")
                }
            }
        }

        StatusSwitch {
            Layout.fillWidth: true
            id: defaultsToggle
            text: qsTr("Follow display zoom")
            leftSide: false
            checked: slider.value === d.nativeWindowDpr
            onToggled: {
                if(checked)
                    d.resetToDefaults()
                d.dirty = true
            }
            StatusToolTip {
                visible: parent.hovered && !parent.pressed
                offset: -(x + width/2 - parent.width/2)
                text: qsTr("Apply your system settings defaults values")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.bigPadding
            StatusSlider {
                Layout.fillWidth: true
                id: slider
                from: d.nativeWindowDpr/2 // half of the baseline
                to: d.nativeWindowDpr*2 // twice the baseline
                value: d.windowDpr
                stepSize: 0.05 // steps of 5%
                snapMode: Slider.SnapAlways
                onMoved: d.dirty = true
            }
            StatusBaseText {
                Layout.preferredWidth: textMetrics.advanceWidth
                font.weight: Font.DemiBold
                color: Theme.palette.primaryColor1
                horizontalAlignment: Qt.AlignRight
                text: "%1%".arg(Math.round(slider.value * 100))
                TextMetrics {
                    id: textMetrics
                    text: "999%"
                }
            }
        }
    }
}
