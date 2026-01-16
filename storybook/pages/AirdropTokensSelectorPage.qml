import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import AppLayouts.Communities.controls

import utils

ColumnLayout {
    readonly property var items: [
        {
            tokenText: "2 MCT",
            networkText: "Ethereum",
            tokenImage: Assets.png("tokens/SNT"),
            networkImage: Assets.svg("network/ethereum"),
            valid: true
        },
        {
            tokenText: "64 DAI",
            networkText: "Optimism",
            tokenImage: Assets.png("tokens/DAI"),
            networkImage: Assets.svg("network/optimism"),
            valid: false
        },
        {
            tokenText: "0.125 ETH",
            networkText: "Arbitrum",
            tokenImage: Assets.png("tokens/ETH"),
            networkImage: Assets.svg("network/arbitrum"),
            valid: true
        }
    ]

    Item {
        Layout.fillHeight: true
        Layout.fillWidth: true

        AirdropTokensSelector {
            anchors.centerIn: parent
            placeholderText: "Example: Empty items"

            property int counter: 0

            model: ListModel {
                id: listModel
            }

            addButton.onClicked: model.append(items[(counter++) % items.length])
            onItemClicked: model.remove(index)

            Component.onCompleted: model.append(items[counter++])
        }
    }

    Button {
        Layout.bottomMargin: 10
        Layout.alignment: Qt.AlignHCenter

        text: "Clear list"
        onClicked: listModel.clear()
    }
}

// category: Components

// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22602-495563
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22628-494998
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=22647-501909
