import QtQuick
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Popups.Dialog
import StatusQ.Core.Theme

StatusAdaptiveDialog {
    id: root

    required property string name
    required property string introMessage
    required property string image
    required property string color

    title: qsTr("%1 community rules").arg(root.name)
    destroyOnClose: true

    contentComponent: ColumnLayout {
        spacing: 24

        StatusSmartIdenticon {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 1
            Layout.bottomMargin: 1
            name: asset.isImage ? "" : root.name
            asset.isImage: root.image !== ""
            asset.name: root.image
            asset.isLetterIdenticon: !asset.isImage
            asset.color: root.color
            asset.charactersLen: 1
            asset.useAcronymForLetterIdenticon: false
            asset.width: 64
            asset.height: 64
        }

        StatusBaseText {
            text: root.introMessage
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }

    footerRightButtons: ObjectModel {
        StatusButton {
            objectName: "communityRulesPopupDoneButton"
            text: qsTr("Done")
            onClicked: root.close()
        }
    }
}
