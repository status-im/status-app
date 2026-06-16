import QtQuick
import QtQml.Models

import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups.Dialog

import utils

import AppLayouts.Communities.controls
import AppLayouts.Communities.panels

StatusDialog {
    id: root

    // expected roles:
    //
    // title (string)
    // feeText (string)
    // error (bool), optional
    property alias model: feesPanel.model

    property alias errorText: footer.errorText
    property alias totalFeeText: footer.totalFeeText
    property alias accountName: footer.accountName

    property bool migratedToColdWallet: false

    signal signTransactionClicked()
    signal cancelClicked()

    QtObject {
        id: d

        property int minTextWidth: 50
    }

    implicitWidth: 600 // by design

    contentItem: FeesPanel {
        id: feesPanel

        highlightFees: false

        footer: FeesSummaryFooter {
            id: footer
        }
    }

    footer: StatusDialogFooter {
        spacing: Theme.padding
        rightButtons: ObjectModel {
            StatusButton {
                objectName: "cancelButton"
                text: qsTr("Cancel")
                type: StatusBaseButton.Type.Danger
                onClicked: {
                    root.cancelClicked()
                    root.close()
                }
            }
            StatusButton {
                objectName: "signTransactionButton"
                enabled: root.errorText === "" && !root.isFeeLoading
                icon.name: root.migratedToColdWallet ? "keycard" : "password"
                text: qsTr("Sign transaction")
                onClicked: {
                    root.signTransactionClicked()
                    root.close()
                }
            }
        }
    }
}
