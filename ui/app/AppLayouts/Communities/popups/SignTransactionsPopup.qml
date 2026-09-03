import QtQuick
import QtQml.Models

import StatusQ.Controls
import StatusQ.Popups.Dialog

import utils

import AppLayouts.Communities.controls
import AppLayouts.Communities.panels

StatusAdaptiveDialog {
    id: root

    // expected model roles:
    //
    // title (string)
    // feeText (string)
    // error (bool), optional
    property var model

    property string errorText
    property string totalFeeText
    property string accountName

    property string keyUid: ""
    property bool migratedToColdWallet: false

    signal signTransactionClicked()
    signal cancelClicked()

    maximumWidthOverride: 600 // by design

    contentComponent: FeesPanel {
        highlightFees: false

        model: root.model

        footer: FeesSummaryFooter {
            errorText: root.errorText
            totalFeeText: root.totalFeeText
            accountName: root.accountName
        }
    }

    footerRightButtons: ObjectModel {
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
            enabled: root.errorText === ""
            icon.name: Utils.resolveAuthSignIcon(root.keyUid, root.migratedToColdWallet, Constants.AuthSignPurpose.General)
            text: qsTr("Sign transaction")
            onClicked: {
                root.signTransactionClicked()
                root.close()
            }
        }
    }
}
