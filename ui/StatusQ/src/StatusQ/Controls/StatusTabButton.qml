pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components

/*!
   \qmltype StatusTabButton
   \inherits TabButton
   \inqmlmodule StatusQ.Controls
   \since StatusQ.Controls 0.1
   \brief StatusTabButton is used in conjunction with a StatusTabBar

   It's customized from Qt's \l{https://doc.qt.io/qt-5/qml-qtquick-controls2-tabbutton.html}{TabButton}, adding:
    - transparent background
    - theme-styled text
    - styled underscore for active state
    - `StatusBadge` to the right from the text

   An alias `badge` property is added to control the `StatusBadge` behaviour and content.
*/

TabButton {
    id: root

    readonly property alias badge: statusBadge

    horizontalPadding: 0

    background: null

    font.family: Fonts.baseFont.family
    font.weight: Font.Medium
    font.pixelSize: Theme.primaryTextFontSize

    hoverEnabled: enabled

    opacity: enabled ? 1 : ThemeUtils.disabledOpacity

    spacing: Theme.smallPadding

    contentItem: ColumnLayout {
        spacing: root.spacing
        RowLayout {
            Layout.fillWidth: true
            spacing: root.spacing

            StatusBaseText {
                Layout.fillWidth: true
                elide: Qt.ElideRight
                font: root.font
                color: !enabled ? Theme.palette.baseColor1 : root.checked || root.hovered ? Theme.palette.directColor1 : Theme.palette.baseColor1
                Behavior on color {ColorAnimation {duration: ThemeUtils.AnimationDuration.Fast}}
                text: root.text
            }

            StatusBadge {
                id: statusBadge
                visible: value > 0
            }
        }
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            Layout.preferredWidth: 24
            Layout.preferredHeight: 2
            opacity: root.checked || root.hovered ? 1 : 0
            Behavior on opacity {OpacityAnimator {duration: ThemeUtils.AnimationDuration.Fast}}
            radius: 4
            color: root.checked ? Theme.palette.primaryColor1 : Theme.palette.primaryColor2
            Behavior on color {ColorAnimation {duration: ThemeUtils.AnimationDuration.Fast}}
        }
    }

    HoverHandler {
        cursorShape: root.enabled ? Qt.PointingHandCursor : undefined
    }
}
