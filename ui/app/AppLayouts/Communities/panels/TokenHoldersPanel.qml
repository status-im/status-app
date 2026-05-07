import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups

import utils
import shared.controls

Control {
    id: root
    property var model
    property string tokenName
    property bool isSelectorMode: false

    signal selfDestructAmountChanged(string walletAddress, int amount)
    signal selfDestructRemoved(string walletAddress)
    bottomPadding: 16

    TokenHoldersProxyModel {
        id: filteredModel
        sourceModel: root.model
        searchText: searcher.text

        sortBy: holdersList.sortBy
        sortOrder: holdersList.sortOrder ? Qt.DescendingOrder : Qt.AscendingOrder
    }

    contentItem: ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.topMargin: Theme.padding
        spacing: 0
        StatusBaseText {
            id: txtLabel
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            wrapMode: Text.Wrap
            font.pixelSize: Theme.primaryTextFontSize
            color: Theme.palette.baseColor1

            text: qsTr("%1 token hodlers").arg(root.tokenName)
        }

        SearchBox {
            id: searcher
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            Layout.preferredHeight: 36
            visible: !root.empty
            placeholderText: qsTr("Search hodlers")
        }
        StatusBaseText {
            id: anotherLabel
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding

            wrapMode: Text.Wrap
            font.pixelSize: Theme.primaryTextFontSize
            color: Theme.palette.baseColor1
            visible: (searcher.text.length > 0 && filteredModel.count === 0)
            text: visible ? qsTr("No hodlers found") : ""
        }
        TokenHoldersList {
            id: holdersList
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 12
            isSelectorMode: root.isSelectorMode
            model: filteredModel
            onSelfDestructRemoved: root.selfDestructRemoved(walletAddress)
            onSelfDestructAmountChanged: root.selfDestructAmountChanged(
                                             walletAddress, amount)
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            Layout.alignment: Qt.AlignBottom
            color: Theme.palette.baseColor2
            opacity: holdersList.bottomSeparatorVisible ? 1.0 : 0.0
        }
    }
}
