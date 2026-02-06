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

StatusListItem {
    id: root

    property SharedStores.NetworkConnectionStore networkConnectionStore
    property var rootStore  // Injected from parent, not singleton
    
    // Model providing active networks
    // Expected roles: chainId (int), chainName (string), iconUrl (string), layer (int)
    property var activeNetworksModel
    property string address
    property string ensName
    property var tags
    property string avatar

    property bool showButtons: sensor.containsMouse

    property alias sendButton: sendButton
    property alias starButton: starButton

    signal openSendModal(string recipient)
    signal menuRequested(string name, string address, string ensName, var tags)

    objectName: title || "followingAddressDelegate"
    subTitle: root.address  // Always show address (title shows ENS if available)

    border.color: Theme.palette.baseColor5

    asset {
        width: 40
        height: 40
        name: root.avatar || ""
        color: Theme.palette.primaryColor1
        isLetterIdenticon: !root.avatar
        letterIdenticonBgWithAlpha: true
    }

    statusListItemIcon.hoverEnabled: true

    statusListItemComponentsSlot.spacing: 0

    QtObject {
        id: d

        readonly property string visibleAddress: !!root.ensName ? root.ensName : root.address
        
        property int savedAddressesVersion: 0
        
        readonly property bool isAddressSaved: {
            savedAddressesVersion
            if (!root.rootStore) return false
            const savedAddr = root.rootStore.getSavedAddress(root.address)
            return savedAddr && savedAddr.address !== ""
        }
    }
    
    Connections {
        target: root.rootStore
        
        function onSavedAddressAddedOrUpdated(added, name, address, errorMsg) {
            if (address.toLowerCase() === root.address.toLowerCase()) {
                d.savedAddressesVersion++
            }
        }
        
        function onSavedAddressDeleted(name, address, errorMsg) {
            if (address.toLowerCase() === root.address.toLowerCase()) {
                d.savedAddressesVersion++
            }
        }
    }

    components: [
        StatusRoundButton {
            id: sendButton
            visible: !!root.title && root.showButtons
            type: StatusRoundButton.Type.Quinary
            radius: Theme.radius
            icon.name: "send"
            enabled: root.networkConnectionStore.sendBuyBridgeEnabled
            onClicked: root.openSendModal(d.visibleAddress)
        },
        StatusRoundButton {
            id: starButton
            visible: !!root.title && (d.isAddressSaved || root.showButtons)
            type: StatusRoundButton.Type.Quinary
            radius: Theme.radius
            icon.name: d.isAddressSaved ? "star-icon" : "star-icon-outline"
            onClicked: {
                if (d.isAddressSaved) {
                    Global.openDeleteSavedAddressesPopup({
                        name: root.ensName || root.address,
                        address: root.address,
                        ens: root.ensName,
                        colorId: ""
                    })
                } else {
                    let nameToUse = root.ensName || root.address
                    if (root.ensName && root.ensName.includes(".")) {
                        nameToUse = root.ensName.split(".")[0]
                    }

                    Global.openAddEditSavedAddressesPopup({
                        addAddress: true,
                        address: root.address,
                        name: nameToUse,
                        ens: root.ensName
                    })
                }
            }

            StatusToolTip {
                text: d.isAddressSaved ? qsTr("Remove from saved addresses") : qsTr("Add to saved addresses")
                visible: starButton.hovered
            }
        },
        StatusRoundButton {
            objectName: "followingAddressView_Delegate_menuButton_" + root.title
            visible: !!root.title
            enabled: root.showButtons
            type: StatusRoundButton.Type.Quinary
            radius: Theme.radius
            icon.name: "more"
            onClicked: {
                root.menuRequested(root.title, root.address, root.ensName, root.tags)
            }

        }
    ]
}
