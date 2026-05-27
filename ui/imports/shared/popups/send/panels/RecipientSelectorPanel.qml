import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils
import shared.controls as SharedControls
import shared.stores
import shared.popups.send

import AppLayouts.Wallet

import StatusQ.Controls
import StatusQ.Popups
import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils

import "../controls"
import "../views"

Item {
    id: root

    property var savedAddressesModel
    property var myAccountsModel
    property var recentRecipientsModel

    readonly property bool recentRecipientsTabVisible: recipientTypeTabBar.currentIndex === 2 // Recent tab

    // This should only pass a `key` role to identify the object but not necessary to pass the complete object structure
    // TODO issue: #15492
    signal recipientSelected(var recipient, int type)
    signal recentRecipientsTabSelected

    enum Type {
        Address,
        Account,
        SavedAddress,
        RecentsAddress,
        None
    }

    StatusTabBar {
        id: recipientTypeTabBar
        objectName: "recipientTypeTabBar"

        anchors.top: parent.top
        anchors.left: parent.left
        width: parent.width

        StatusTabButton {
            width: implicitWidth
            objectName: "savedAddressesTab"
            text: qsTr("Saved")
        }
        StatusTabButton {
            width: implicitWidth
            objectName: "myAccountsTab"
            text: qsTr("My Accounts")
        }
        StatusTabButton {
            width: implicitWidth
            objectName: "recentAddressesTab"
            text: qsTr("Recent")
        }
    }

    // To-do adapt to new design and make block white/black once the list items etc support new color scheme
    Rectangle {
        anchors.top: recipientTypeTabBar.bottom
        anchors.topMargin: -5
        height: parent.height - recipientTypeTabBar.height
        width: parent.width
        color: Theme.palette.indirectColor1
        radius: 8

        StackLayout {
            currentIndex: recipientTypeTabBar.currentIndex
            anchors.fill: parent

            StatusListView {
                id: savedAddresses
                objectName: "savedAddressesList"

                model: root.savedAddressesModel
                header: savedAddresses.count > 0 ? search : nothingInList
                headerPositioning: ListView.OverlayHeader
                delegate: SavedAddressListItem {
                    implicitWidth: ListView.view.width
                    modelData: model
                    visible: !savedAddresses.headerItem.text || name.toLowerCase().includes(savedAddresses.headerItem.text)
                    // This should only pass a `key` role to identify the saved addresses object but not necessary to pass the complete object structure
                    // TODO issue: #15492
                    onClicked: recipientSelected(modelData, Helpers.RecipientAddressObjectType.SavedAddress)
                }
                Component {
                    id: search
                    SearchBoxWithRightIcon {
                        width: parent.width
                        placeholderText: qsTr("Search for saved address")
                        z: 2
                    }
                }
                Component {
                    id: nothingInList
                    StatusBaseText {
                        width: savedAddresses.width
                        height: visible ? 56 : 0
                        font.pixelSize: Theme.primaryTextFontSize
                        color: Theme.palette.directColor1
                        text: qsTr("No Saved Address")
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            StatusListView {
                id: myAccounts
                objectName: "myAccountsList"

                delegate: SharedControls.WalletAccountListItem {
                    required property var model

                    implicitWidth: ListView.view.width
                    name: model.name
                    address: model.address

                    emoji: model.emoji
                    walletColor: Utils.getColorForId(Theme.palette, model.colorId)
                    currencyBalance: model.currencyBalance
                    walletType: model.walletType
                    migratedToColdWallet: model.migratedToColdWallet ?? false
                    accountBalance: model.accountBalance ?? null
                    // This should only pass a `key` role to identify the accounts object but not necessary to pass the complete object structure
                    // TODO issue: #15492
                    onClicked: recipientSelected({name: model.name,
                                                     address: model.address,
                                                     color: model.color,
                                                     colorId: model.colorId,
                                                     emoji: model.emoji,
                                                     walletType: model.walletType,
                                                     currencyBalance: model.currencyBalance,
                                                     migratedToColdWallet: model.migratedToColdWallet
                                                 },
                                                 Helpers.RecipientAddressObjectType.Account)

                    }

                model: root.myAccountsModel
            }

            StatusListView {
                id: recents
                objectName: "recentReceiversList"

                header: StatusBaseText {
                    height: visible ? 56 : 0
                    width: recents.width
                    font.pixelSize: Theme.primaryTextFontSize
                    color: Theme.palette.directColor1
                    text: qsTr("No Recents")
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    visible: recents.count <= 0
                }

                delegate: StatusListItem {
                    id: listItem

                    property var entry: activityEntry
                    property bool isIncoming: entry.txType === Constants.TransactionType.Receive

                    implicitWidth: ListView.view.width
                    height: visible ? 64 : 0
                    title: isIncoming ? StatusQUtils.Utils.elideText(entry.sender,6,4) : StatusQUtils.Utils.elideText(entry.recipient,6,4)
                    subTitle: LocaleUtils.getTimeDifference(new Date(parseInt(entry.timestamp) * 1000), new Date())
                    statusListItemTitle.elide: Text.ElideMiddle
                    statusListItemTitle.wrapMode: Text.NoWrap
                    radius: 0
                    color: sensor.containsMouse || highlighted ? Theme.palette.baseColor2 : "transparent"
                    statusListItemComponentsSlot.spacing: 5
                    components: [
                        StatusIcon {
                            id: transferIcon
                            height: 15
                            width: 15
                            color: listItem.isIncoming ? Theme.palette.successColor1 : Theme.palette.dangerColor1
                            icon: listItem.isIncoming ? "arrow-down" : "arrow-up"
                            rotation: 45
                        },
                        StatusTextWithLoadingState {
                            font.pixelSize: Theme.primaryTextFontSize
                            customColor: Theme.palette.directColor1
                            text: LocaleUtils.currencyAmountToLocaleString(entry.amountCurrency)
                        }
                    ]
                    // This should only pass a `key` role to identify the recent activity object but not necessary to pass the complete object structure
                    // TODO issue: #15492
                    onClicked: recipientSelected(entry, Helpers.RecipientAddressObjectType.RecentsAddress)
                }

                model: root.recentRecipientsModel

                onVisibleChanged: {
                    if (visible) {
                        root.recentRecipientsTabSelected()
                    }
                }
            }
        }
    }
}
