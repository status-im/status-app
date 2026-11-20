import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Wallet.controls

import StatusQ.Core.Theme

SplitView {
    id: root
    Pane {
        id: leftPane
        SplitView.fillWidth: true
        SplitView.fillHeight: true
        BannerCard {
            anchors.centerIn: parent
            title: titleField.text
            subTitle: subTitleField.text
            image: Assets.png("wallet/wallet-green")
            closeEnabled: closeEnabled.checked
            onClicked: {
                console.info("BannerCard clicked")
            }
            onClose: {
                console.info("BannerCard closed")
            }
        }
    }
    Pane {
        id: rightPane
        SplitView.fillHeight: true
        SplitView.preferredWidth: 300
        ColumnLayout {
            anchors.fill: parent
            CheckBox {
                id: closeEnabled
                text: "Show close button"
                checked: true
            }
            Label {
                text: "Title"
            }
            TextField {
                Layout.fillWidth: true
                id: titleField
                text: "Ways to buy crypto"
            }
            Label {
                text: "Sub title"
            }
            TextField {
                Layout.fillWidth: true
                id: subTitleField
                text: "Via card or bank transfer"
            }
            Item {
                Layout.fillHeight: true
            }
        }
    }
}

// category: Components
// status: good
