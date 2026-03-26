import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

import utils

Control {
    id: root

    property int qualifyingAddresses: 1
    property int knownAddresses: 1
    property int unknownAddresses: 1

    verticalPadding: 16
    horizontalPadding: 18

    background: Rectangle {
        border.color: Theme.palette.border
        radius: Theme.radius
        color: StatusColors.transparent
    }

    contentItem: RowLayout {
        spacing: 4

        StatusIcon {
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22

            Layout.alignment: Qt.AlignTop

            color: Theme.palette.baseColor1
            icon: "communities"
        }

        StatusBaseText {
            Layout.fillWidth: true

            wrapMode: Text.Wrap

            font.pixelSize: Theme.primaryTextFontSize
            lineHeight: 22
            lineHeightMode: Text.FixedHeight

            Binding on color {
                when: qualifyingAddresses === 0
                value: root.Theme.palette.dangerColor1
            }

            readonly property real ratio: 100 * qualifyingAddresses / knownAddresses
            readonly property string ratioAligned: Number(ratio.toFixed(1))

            readonly property string part1: qsTr("%L1% of the %Ln community member(s) with known addresses will qualify for this permission.",
                                                 "", knownAddresses).arg(ratioAligned)
            readonly property string part2: qsTr("The addresses of %Ln community member(s) are unknown.", "", unknownAddresses)

            text: `${part1} ${part2}`
        }
    }
}
