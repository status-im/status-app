import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Popups

import utils
import shared.controls

Control {
    id: root

    // Join of MembersModel and TokenHoldersModel
    // Expected roles: name, walletAddress, imageSource, NumberOfMessages, amount, pubkey,
    // isContact, isVerified, isEnsVerified, trustStatus, nickName, userName, compressedPubKey,
    // memberRole, iconName, isUntrustworthy, onlineStatus
    property var model

    property string tokenName
    property bool showRemotelyDestructMenuItem: true
    property alias isAirdropEnabled: infoBoxPanel.buttonEnabled
    property int multiplierIndex: 0

    readonly property alias sortBy: holdersList.sortBy
    readonly property alias sorting: holdersList.sortOrder

    readonly property bool empty: countCheckHelper.count === 0

    signal viewProfileRequested(string contactId)
    signal viewMessagesRequested(string contactId)
    signal airdropRequested(string address)
    signal remoteDestructRequested(string name, string address)
    signal kickRequested(string name, string contactId, string address)
    signal banRequested(string name, string contactId, string address)

    signal generalAirdropRequested

    Instantiator {
        id: countCheckHelper

        model: root.model
        delegate: QtObject {}
    }

    TokenHoldersProxyModel {
        id: proxyModel

        sourceModel: root.model || null
        searchText: searcher.text

        sortBy: holdersList.sortBy
        sortOrder: holdersList.sortOrder ? Qt.DescendingOrder : Qt.AscendingOrder
    }

    QtObject {
        id: d

        readonly property int red2Color: 4
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        spacing: 0

        StatusBaseText {
            Layout.fillWidth: true

            wrapMode: Text.Wrap
            font.pixelSize: Theme.primaryTextFontSize
            color: Theme.palette.baseColor1

            text: qsTr("%1 token hodlers").arg(root.tokenName)
        }

        SearchBox {
            id: searcher

            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.preferredHeight: 36

            visible: !root.empty

            placeholderText: qsTr("Search hodlers")
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.topMargin: 12

            wrapMode: Text.Wrap
            font.pixelSize: Theme.primaryTextFontSize
            color: Theme.palette.baseColor1

            visible: searcher.text.length > 0

            text: (searcher.text.length > 0 && proxyModel.count > 0)
                  ? qsTr("Search results") : qsTr("No hodlers found")
        }

        StatusInfoBoxPanel {
            id: infoBoxPanel

            Layout.fillWidth: true
            Layout.topMargin: Theme.padding

            visible: root.empty
            title: qsTr("No hodlers just yet")
            text: qsTr("You can Airdrop tokens to deserving Community members or to give individuals token-based permissions.")
            buttonText: qsTr("Airdrop")

            onClicked: root.generalAirdropRequested()
        }

        SortableTokenHoldersList {
            id: holdersList

            visible: !root.empty && proxyModel.count > 0
            multiplierIndex: root.multiplierIndex

            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight
            Layout.topMargin: 20

            model: proxyModel

            onClicked: {
                if (mouse.button !== Qt.RightButton)
                    return

                const entry = SQUtils.ModelUtils.get(proxyModel, index)

                menu.contactId = entry.pubKey
                menu.name = entry.name
                menu.currentAddress = entry.walletAddress
                menu.popup(parent, mouse.x, mouse.y)

                holdersList.currentIndex = index
            }
        }
    }

    StatusMenu {
        id: menu

        property string contactId
        property string name
        property string currentAddress
        readonly property bool rawAddress: name === ""

        onClosed: holdersList.currentIndex = -1

        StatusAction {
            text: qsTr("View Profile")
            icon.name: "profile"
            enabled: !menu.rawAddress

            onTriggered: root.viewProfileRequested(menu.contactId)
        }

        StatusAction {
            text: qsTr("View Messages")
            icon.name: "chat"
            enabled: !menu.rawAddress

            onTriggered: root.viewMessagesRequested(menu.contactId)
        }

        StatusAction {
            text: qsTr("Airdrop")
            icon.name: "airdrop"

            onTriggered: root.airdropRequested(menu.currentAddress)
        }

        StatusMenuSeparator {
            visible: remotelyDestructAction.enabled || kickAction.enabled
                     || banAction.enabled
        }

        StatusAction {
            id: remotelyDestructAction

            text: qsTr("Remotely destruct")
            icon.name: "destroy"
            enabled: root.showRemotelyDestructMenuItem
            type: StatusBaseButton.Type.Danger

            onTriggered: root.remoteDestructRequested(menu.name,
                                                      menu.currentAddress)
        }

        StatusAction {
            id: kickAction

            text: qsTr("Kick")
            icon.name: "warning"
            enabled: !menu.rawAddress
            type: StatusBaseButton.Type.Danger

            onTriggered: root.kickRequested(menu.name, menu.contactId,
                                            menu.currentAddress)
        }

        StatusAction {
            id: banAction

            text: qsTr("Ban")
            icon.name: "cancel"
            enabled: !menu.rawAddress
            type: StatusBaseButton.Type.Danger

            onTriggered: root.banRequested(menu.name, menu.contactId,
                                           menu.currentAddress)
        }
    }
}
