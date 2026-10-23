import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

Rectangle {
    id: root

    required property int checkState
    required property bool mirrored
    required property bool hovered
    property int size: StatusCheckBox.Size.Regular

    implicitWidth: size === StatusCheckBox.Size.Regular
                   ? d.indicatorSizeRegular : d.indicatorSizeSmall
    implicitHeight: implicitWidth

    radius: 6

    QtObject {
        id: d

        readonly property int indicatorSizeRegular: 24
        readonly property int indicatorSizeSmall: 18

        readonly property int indicatorIconWidthRegular: 13
        readonly property int indicatorIconWidthSmall: 9

        readonly property int indicatorIconHeightRegular: 11
        readonly property int indicatorIconHeightSmall: 7
    }
    
    StatusIcon {
        id: icon
        icon: "check"
        width: root.size === StatusCheckBox.Size.Regular
               ? d.indicatorIconWidthRegular : d.indicatorIconWidthSmall
        height: root.size === StatusCheckBox.Size.Regular
                ? d.indicatorIconHeightRegular : d.indicatorIconHeightSmall
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1
        anchors.horizontalCenterOffset: root.mirrored ? - 1 : 1
        opacity: root.checkState === Qt.Checked ? 1 : 0
        visible: opacity > 0
        Behavior on color {ColorAnimation {duration: ThemeUtils.AnimationDuration.Fast}}
    }

    Rectangle {
        id: partialCheckIcon
        anchors.centerIn: parent
        width: parent.width * .6
        height: root.size === StatusCheckBox.Size.Regular ? 2 : 1
        radius: height/2
        visible: root.checkState === Qt.PartiallyChecked
    }

    states: [
        State {
            name: "hovered"
            when: root.hovered && root.enabled
            extend: "enabled"
            PropertyChanges {
                icon {
                    opacity: root.checkState === Qt.Unchecked ? 0.5 : root.checkState === Qt.Checked ? 1 : 0
                }
            }
        },
        State {
            name: "enabled"
            when: root.enabled
            PropertyChanges {
                root {
                    color: root.checkState === Qt.Unchecked ? root.Theme.palette.transparent
                                                            : root.Theme.palette.primaryColor3
                    border.width: 2
                    border.color: root.checkState === Qt.Unchecked ? root.Theme.palette.separator
                                                                   : root.Theme.palette.transparent
                }
                icon {
                    color: root.Theme.palette.primaryColor1
                }
                partialCheckIcon {
                    color: root.Theme.palette.primaryColor1
                }
            }
        },
        State {
            name: "disabled"
            when: !root.enabled
            PropertyChanges {
                root {
                    color: root.Theme.palette.baseColor2
                    border.color: root.Theme.palette.transparent
                }
                icon {
                    color: root.checkState === Qt.Unchecked ? root.Theme.palette.transparent
                                                            : root.Theme.palette.baseColor1
                }
                partialCheckIcon {
                    color: root.checkState === Qt.Unchecked ? root.Theme.palette.transparent
                                                            : root.Theme.palette.baseColor1
                }
            }
        }
    ]
}
