import QtQuick

import StatusQ.Popups.Dialog
import StatusQ.Core.Theme

import shared.panels

StatusDialog {
    width: 600
    title: qsTr("Open app menu")
    implicitHeight: 420 + 2 * Theme.padding
    contentItem: SVGImage {
        height: parent.height
        source: (Theme.style === Theme.Light) ? Assets.svgImg("open-menu-education-light") :
                                                Assets.svgImg("open-menu-education-dark")
    }
    footer.visible: false
}
