import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import shared.popups.walletconnect.PairWCModal

import Storybook

SplitView {
    id: root

    ColumnLayout {
        SplitView.fillHeight: true
        SplitView.fillWidth: true

        WCUriInput {
            id: wcInput
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignCenter
            Layout.margins: 16
        }

        Component.onCompleted: {
            function onVisibilityChangedAfterCreation() {
                let items = InspectionUtils.findVisualsByTypeName(wcInput, "StatusTextArea")
                if (items.length === 1) {
                    items[0].text = "wc:825fbaeb53eeeb08e53a8ddf40cec7996056f49647ab5c39663a2a102920d81c@2?expiryTimestamp=1719495004&relay-protocol=irn&symKey=2eaa97fa11774efb67fd7c93efe92773a7b60650c5cb2621abbdba02cdd4040c"
                }
                wcInput.visibleChanged.disconnect(onVisibilityChangedAfterCreation);
            }
            wcInput.visibleChanged.connect(onVisibilityChangedAfterCreation);
        }

        // Spacer
        Item { Layout.fillHeight: true }
    }

    Pane {
        Layout.fillWidth: true

        ColumnLayout {
            TextInput {
                id: placeHolderInput
                text: "Input state"
            }
            CheckBox {
                id: pendingCheckBox
                text: "pending"
                checked: false

                onCheckedChanged: wcInput.pending = pendingCheckBox.checked
            }
            CheckBox {
                id: validCheckBox
                text: "valid"
                checked: true

                onCheckedChanged: {
                    let items = InspectionUtils.findVisualsByTypeName(wcInput, "StatusTextArea")
                    if (items.length === 1) {
                        items[0].valid = validCheckBox.checked
                    }
                }
            }
        }
    }
}

// category: Components
