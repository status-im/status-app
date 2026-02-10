import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Popups.Dialog
import StatusQ.Core.Theme
import StatusQ.Components

import utils

StatusDialog {
    id: root

    property alias acceptBtnText: acceptBtn.text
    property alias acceptBtn: acceptBtn
    property alias cancelBtn: cancelBtn
    property alias alertText: contentTextItem.text
    property alias alertLabel: contentTextItem
    property alias alertNote: contentNoteItem
    property int acceptBtnType: StatusBaseButton.Type.Danger

    property StatusAssetSettings asset: StatusAssetSettings {
        width: 24
        height: 24
        rotation: 0
        color: root.Theme.palette.primaryColor1
        bgWidth: 40
        bgHeight: 40
        bgColor: root.Theme.palette.primaryColor3
        bgRadius: bgWidth / 2
    }

    signal acceptClicked
    signal cancelClicked

    implicitWidth: 400 // by design
    topPadding: Theme.padding
    bottomPadding: topPadding
    contentItem: Column {
        StatusBaseText {
            id: contentTextItem
            width: parent.width
            font.pixelSize: Theme.primaryTextFontSize
            wrapMode: Text.WordWrap
            lineHeight: 1.2
        }
        StatusBaseText {
            id: contentNoteItem
            visible: false
            width: parent.width
            font.pixelSize: Theme.primaryTextFontSize
            wrapMode: Text.WordWrap
            lineHeight: 1.2
        }
    }

    header: StatusDialogHeader {
        visible: root.title || root.subtitle
        headline.title: root.title
        headline.subtitle: root.subtitle
        actions.closeButton.onClicked: root.close()
        leftComponent: StatusRoundIcon {
            width: visible?  implicitWidth: 0
            visible: !!root.asset.name
            asset: root.asset
        }
    }

    footer: StatusDialogFooter {
        spacing: Theme.padding
        rightButtons: ObjectModel {

            StatusButton {
                id: cancelBtn
                text: qsTr("Cancel")
                normalColor: "transparent"

                onClicked: {
                    root.cancelClicked()
                    close()
                }
            }

            StatusButton {
                id: acceptBtn

                type: root.acceptBtnType

                Component.onCompleted: acceptBtn.forceActiveFocus()

                onClicked: {
                    root.acceptClicked()
                    close()
                }
            }
        }
    }
}
