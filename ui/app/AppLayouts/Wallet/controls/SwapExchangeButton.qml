import QtQuick
import QtQuick.Controls

import StatusQ.Controls
import StatusQ.Core.Theme

StatusButton {
    implicitWidth: 32
    implicitHeight: 32

    // A single up/down glyph that stays put: the previous arrow-down/arrow-up pair flipped
    // direction on hover, which reads as the button having changed what it will do.
    // The button is round, so rotating it only rotates the glyph.
    rotation: 90
    icon.name: "exchange"
    icon.width: 16
    icon.height: 16
    icon.color: Theme.palette.baseColor1

    focusPolicy: Qt.NoFocus
    isRoundIcon: true
    normalColor: Theme.palette.indirectColor3
    disabledColor: normalColor
    opacity: enabled ? 1 : 0.4
    hoverColor: Theme.palette.directColor8
    borderWidth: 1
    borderColor: hovered ? Theme.palette.directColor7 : Theme.palette.directColor8
}
