import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml
import QtQml.Models

import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core
import StatusQ.Popups.Dialog
import StatusQ.Core.Theme

import utils

StatusDialog {
    id: root

    required property var community

    signal importControlNode(string communityId)

    width: 640

    header: StatusDialogHeader {
        headline.title: qsTr("Make this device the control node for %1").arg(root.community.name)
        actions.closeButton.onClicked: root.close()
        leftComponent: StatusSmartIdenticon {
            width: 32
            height: 32
            name: root.community?.name ?? ""
            asset.name: root.community?.image ?? ""
            asset.isImage: !!asset.name
            asset.color: root.community?.color ?? ""
        }
    }

    closePolicy: Popup.NoAutoClose

    component Paragraph: StatusBaseText {
        Layout.fillWidth: true
        font.pixelSize: Theme.primaryTextFontSize
        lineHeightMode: Text.FixedHeight
        lineHeight: 22
        wrapMode: Text.Wrap
        verticalAlignment: Text.AlignVCenter
    }

    contentItem: ColumnLayout {
        spacing: Theme.padding
        Paragraph {
            text: qsTr("Are you sure you want to make this device the control node for %1? This device should be one that you are able to keep online and running Status at all times to enable the Community to function correctly.").arg(root.community.name)
        }
        StatusDialogDivider {
            Layout.fillWidth: true
        }
        Paragraph {
            text: qsTr("I acknowledge that...")
        }
        StatusCheckBox {
            id: agreementCheckBox
            Layout.fillWidth: true
            font.pixelSize: Theme.primaryTextFontSize
            text: qsTr("I must keep this device online and running Status")
        }
        StatusCheckBox {
            id: agreementCheckBox2
            Layout.fillWidth: true
            font.pixelSize: Theme.primaryTextFontSize
            text: qsTr("My other synced device will cease to be the control node for this Community")
        }
    }

    footer: StatusDialogFooter {
        rightButtons: ObjectModel {
            StatusFlatButton {
                text: qsTr("Cancel")
                onClicked: root.close()
            }
            StatusButton {
                text: qsTr("Make this device the control node for %1").arg(root.community.name)
                enabled: agreementCheckBox.checked && agreementCheckBox2.checked
                onClicked: {
                    root.importControlNode(root.community.id)
                    root.close()
                }
            }
        }
    }
}
