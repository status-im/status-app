import QtQuick
import QtQuick.Controls
import QtQml.Models

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups.Dialog
import StatusQ.Components

import utils

StatusDialog {
    id: root

    property int mode: TransferOwnershipAlertPopup.Mode.TransferOwnership

    // Community related props:
    required property string communityName
    required property string communityLogo

    signal mintClicked
    signal cancelClicked

    enum Mode {
        TransferOwnership,
        MoveControlNode
    }

    QtObject {
        id: d

        readonly property string headerTitle: (root.mode === TransferOwnershipAlertPopup.Mode.TransferOwnership) ?
                                                  qsTr("Transfer ownership of %1").arg(root.communityName) :
                                                  qsTr("How to move the %1 control node to another device").arg(root.communityName)
        readonly property string alertText: (root.mode === TransferOwnershipAlertPopup.Mode.TransferOwnership) ?
                                                qsTr("<b>It looks like you haven’t minted the %1 Owner token yet.</b> Once you have minted this token, you can transfer ownership of %1 by sending the Owner token to the account of the person you want to be the new Community owner.").arg(root.communityName) :
                                                qsTr("<b>It looks like you haven’t minted the %1 Owner token yet.</b> Once you have minted this token, you can make one of your other synced desktop devices the control node for the %1 Community.").arg(root.communityName)
    }

    width: 640 // by design
    padding: Theme.padding
    contentItem: StatusBaseText {
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        text: d.alertText
        lineHeight: 1.2
    }

    header: StatusDialogHeader {
        headline.title: d.headerTitle
        actions.closeButton.onClicked: root.close()
        leftComponent: StatusRoundedImage {
            image.source: root.communityLogo
        }
    }

    footer: StatusDialogFooter {
        spacing: Theme.padding
        rightButtons: ObjectModel {
            StatusFlatButton {
                text: qsTr("Cancel")

                onClicked: {
                    root.cancelClicked()
                    root.close()
                }
            }

            StatusButton {
                text: qsTr("Mint %1 Owner token").arg(root.communityName)

                onClicked: {
                    root.mintClicked()
                    root.close()
                }
            }
        }
    }
}
