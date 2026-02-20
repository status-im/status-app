import QtQuick
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Popups.Dialog
import StatusQ.Core.Theme

StatusDialog {
    id: root

    required property string name
    required property string introMessage
    required property string image
    required property string color
    

    implicitWidth: 640 // design
    title: qsTr("%1 community rules").arg(root.name)

    onClosed: destroy()

    contentItem: StatusScrollView {
        id: scrollView
        contentWidth: availableWidth
        padding: 0

        ColumnLayout {
            width: scrollView.availableWidth
            spacing: 24

            StatusSmartIdenticon {
                Layout.alignment: Qt.AlignHCenter
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
                Layout.fillHeight: true
                wrapMode: Text.WordWrap
            }
        }
    }

    footer: StatusDialogFooter {
        bottomPadding: Theme.padding + root.parent.SafeArea.margins.bottom
        rightButtons: ObjectModel {
            StatusButton {
                text: qsTr("Done")
                onClicked: root.close()
            }
        }
    }
}
