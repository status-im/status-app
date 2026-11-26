import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

import shared.panels

// Dismissed only by "Ok"
ModuleWarning {
    id: root

    signal acceptRequested()
    signal termsOfUseRequested()
    signal privacyPolicyRequested()

    type: ModuleWarning.Success
    closeBtnVisible: false
    delay: false

    onLinkActivated: (link) => {
        if (link === "#terms")
            root.termsOfUseRequested()
        else if (link === "#privacy")
            root.privacyPolicyRequested()
    }

    actions: RowLayout {
        spacing: Theme.halfPadding

        StatusBaseText {
            objectName: "termsText"
            text: qsTr("By using Status you accept the %1 and %2")
                .arg(`<a href="#terms">${qsTr("Terms of Use")}</a>`)
                .arg(`<a href="#privacy">${qsTr("Privacy Policy")}</a>`)
            font.pixelSize: Theme.additionalTextSize
            font.weight: Font.Medium
            color: Theme.palette.indirectColor1
            linkColor: color
            onLinkActivated: (link) => root.linkActivated(link)

            HoverHandler {
                cursorShape: hovered && parent.hoveredLink ? Qt.PointingHandCursor : undefined
            }
        }
        ModuleWarningButton {
            objectName: "okButton"
            text: qsTr("Ok")
            onClicked: root.acceptRequested()
        }
    }
}
