import QtQuick
import QtQuick.Controls

import utils

import StatusQ
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Popups

import shared.controls
import shared.popups
import shared.stores as SharedStores

import "../popups"
import "../controls"
import "../stores"
import ".."

StatusListItem {
    id: root

    property SharedStores.NetworkConnectionStore networkConnectionStore
    property var activeNetworks
    property string name
    property string address
    property string mixedcaseAddress
    property string ens
    property string colorId
    property string avatar  // Optional ENS avatar URL
    property bool isFollowingAddress: false  // True if from EFP following list, false if saved address

    property int usage: SavedAddressesDelegate.Usage.Delegate
    property bool showButtons: sensor.containsMouse

    property alias menuButtonAlias: menuButton

    property alias sendButton: sendButton

    signal aboutToOpenPopup()
    signal openSendModal(string recipient)

    enum Usage {
        Delegate,
        Item
    }

    implicitWidth: ListView.view ? ListView.view.width : 0

    title: name
    objectName: name
    subTitle: {
        if (ens.length > 0)
            return ens
        else {
            return WalletUtils.addressToDisplay(Theme.palette, root.address, false, sensor.containsMouse)
        }
    }

    border.color: Theme.palette.baseColor5

    asset {
        width: 40
        height: 40
        name: root.avatar || ""  // Use avatar URL if available
        color: Utils.getColorForId(Theme.palette, root.colorId)
        isLetterIdenticon: !root.avatar  // Only use letter identicon if no avatar
        letterIdenticonBgWithAlpha: true
    }

    statusListItemIcon.hoverEnabled: true

    statusListItemComponentsSlot.spacing: 0

    QtObject {
        id: d

        readonly property string visibleAddress: !!root.ens? root.ens : root.address
    }

    onClicked: {
        if (root.usage === SavedAddressesDelegate.Usage.Item) {
            return
        }
        Global.openSavedAddressActivityPopup({
                                                 name: root.name,
                                                 address: root.address,
                                                 mixedcaseAddress: root.mixedcaseAddress,
                                                 ens: root.ens,
                                                 colorId: root.colorId
                                              })
    }

    components: [
        StatusRoundButton {
            id: sendButton
            visible: !!root.name && root.showButtons
            type: StatusRoundButton.Type.Quinary
            radius: 8
            icon.name: "send"
            enabled: root.networkConnectionStore.sendBuyBridgeEnabled
            onClicked: root.openSendModal(d.visibleAddress)
        },
        StatusRoundButton {
            id: menuButton
            objectName: "savedAddressView_Delegate_menuButton_" + root.name
            visible: !!root.name
            enabled: root.showButtons
            type: StatusRoundButton.Type.Quinary
            radius: 8
            icon.name: "more"
            Accessible.name: StatusQUtils.Utils.formatAccessibleName("Options", objectName)
            onClicked: {
                menu.openMenu(this, x + width - menu.width - statusListItemComponentsSlot.spacing, y + height + Theme.halfPadding,
                    {
                        name: root.name,
                        address: root.address,
                        mixedcaseAddress: root.mixedcaseAddress,
                        ens: root.ens,
                        colorId: root.colorId,
                    }
                );
            }

        }
    ]

    StatusMenu {
        id: menu
        property string name
        property string address
        property string mixedcaseAddress
        property string ens
        property string colorId

        readonly property int maxHeight: 341
        height: implicitHeight > maxHeight ? maxHeight : implicitHeight

        function openMenu(parent, x, y, model) {
            menu.name = model.name;
            menu.address = model.address;
            menu.mixedcaseAddress = model.mixedcaseAddress;
            menu.ens = model.ens;
            menu.colorId = model.colorId;
            popup(parent, x, y);
        }
        onClosed: {
            menu.name = "";
            menu.address = "";
            menu.mixedcaseAddress = ""
            menu.ens = ""
            menu.colorId = ""
        }

        StatusAction {
            text: qsTr("Edit saved address")
            objectName: "editSavedAddress"
            assetSettings.name: "pencil-outline"
            enabled: !root.isFollowingAddress
            onTriggered: {
                if (root.usage === SavedAddressesDelegate.Usage.Item) {
                    root.aboutToOpenPopup()
                }
                Global.openAddEditSavedAddressesPopup({
                                                          edit: true,
                                                          address: menu.address,
                                                          name: menu.name,
                                                          ens: menu.ens,
                                                          colorId: menu.colorId
                                                      })
            }
        }

        StatusSuccessAction {
            id: copyAddressAction
            objectName: "copySavedAddressAction"
            successText: qsTr("Address copied")
            text: qsTr("Copy address")
            icon.name: "copy"
            timeout: 1500
            autoDismissMenu: true
            onTriggered: ClipboardUtils.setText(d.visibleAddress)
        }

        StatusAction {
            text: qsTr("Show address QR")
            objectName: "showQrSavedAddressAction"
            assetSettings.name: "qr"
            onTriggered: {
                if (root.usage === SavedAddressesDelegate.Usage.Item) {
                    root.aboutToOpenPopup()
                }
                Global.openShowQRPopup({
                                           showSingleAccount: true,
                                           showForSavedAddress: true,
                                           switchingAccounsEnabled: false,
                                           hasFloatingButtons: false,
                                           name: menu.name,
                                           address: menu.address,
                                           mixedcaseAddress: menu.mixedcaseAddress,
                                           colorId: menu.colorId
                                       })
            }
        }

        StatusMenuSeparator {}

        BlockchainExplorersMenu {
            id: blockchainExplorersMenu
            flatNetworks: root.activeNetworks
            onNetworkClicked: {
                if (root.usage === SavedAddressesDelegate.Usage.Item) {
                    root.aboutToOpenPopup()
                }
                let link = Utils.getUrlForAddressOnNetwork(shortname, isTestnet, d.visibleAddress ? d.visibleAddress : root.ens);
                Global.requestOpenLink(link)
            }
        }

        StatusMenuSeparator { }

        StatusAction {
            text: qsTr("Remove saved address")
            type: StatusAction.Type.Danger
            assetSettings.name: "delete"
            objectName: "deleteSavedAddress"
            enabled: !root.isFollowingAddress
            onTriggered: {
                if (root.usage === SavedAddressesDelegate.Usage.Item) {
                    root.aboutToOpenPopup()
                }
                Global.openDeleteSavedAddressesPopup({
                                                         name: menu.name,
                                                         address: menu.address,
                                                         ens: menu.ens,
                                                         colorId: menu.colorId
                                                     })
            }
        }
    }
}
