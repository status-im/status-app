import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Wallet.controls

import StatusQ.Core.Theme

Control {
    id: root

    property bool closeEnabled: true
    property bool buyEnabled: true
    property bool receiveEnabled: true

    readonly property bool anyVisibleItems: buyCard.visible || receiveCard.visible

    signal buyClicked()
    signal receiveClicked()
    signal closeBuy()
    signal closeReceive()

    // Full-screen overlay resets any card on tap outside.
    Item {
        parent: root.Window.contentItem
        anchors.fill: parent

        PointHandler {
            onActiveChanged: {
                if (active) {
                    buyCard.reset()
                    receiveCard.reset()
                }
            }
        }
    }

    contentItem: RowLayout {
        id: layout
        spacing: Theme.padding

        BannerCard {
            id: buyCard
            objectName: "buyCard"
            Layout.fillWidth: true
            Layout.preferredWidth: root.buyEnabled ? layout.width / layout.children.length : 0
            title: qsTr("Ways to buy")
            subTitle: qsTr("Via card or bank")
            image: Assets.png("wallet/wallet-green")
            closeEnabled: root.closeEnabled
            visible: Layout.preferredWidth > 0
            opacity: root.buyEnabled ? 1 : 0

            onClose: root.closeBuy()
            onClicked: root.buyClicked()

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
            }
            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
            }
        }
        BannerCard {
            id: receiveCard
            objectName: "receiveCard"
            Layout.fillWidth: true
            Layout.preferredWidth: root.receiveEnabled ? layout.width / layout.children.length : 0
            title: qsTr("Receive")
            subTitle: qsTr("Deposit to your Wallet")
            image: Assets.png("wallet/flying-coin")
            closeEnabled: root.closeEnabled
            visible: Layout.preferredWidth > 0
            opacity: root.receiveEnabled ? 1 : 0

            onClose: root.closeReceive()
            onClicked: root.receiveClicked()

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
            }
            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
            }
        }
    }
}
