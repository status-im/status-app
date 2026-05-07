import QtQuick
import QtQuick.Layouts

import StatusQ
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Popups

import utils
import shared
import shared.controls
import shared.panels
import shared.views
import shared.status

import AppLayouts.stores as AppLayoutStores

ColumnLayout {
    id: root
    objectName: "CommunityProfilePopupInviteFrindsPanel_ColumnLayout"

    property string headerTitle: ""

    property var contactsModel
    property var membersModel
    property string communityId

    property var pubKeys: ([])

    spacing: 0

    StyledText {
        id: headline
        text: qsTr("Contacts")
        font.pixelSize: Theme.primaryTextFontSize
        color: Theme.palette.secondaryText
        Layout.leftMargin: Theme.padding
        Layout.rightMargin: Theme.padding
    }

    SearchBox {
        id: filterInput
        placeholderText: qsTr("Search contacts")
        Layout.preferredHeight: 36
        Layout.fillWidth: true
        Layout.topMargin: Theme.bigPadding
        Layout.bottomMargin: Theme.padding
        Layout.leftMargin: Theme.padding
        Layout.rightMargin: Theme.padding
    }

    ExistingContacts {
        contactsModel: root.contactsModel
        membersModel: root.membersModel
        communityId: root.communityId

        hideCommunityMembers: true
        showCheckbox: true
        filterText: filterInput.text
        pubKeys: root.pubKeys
        onContactClicked: function (contact) {
            if (!contact || typeof contact === "string") {
                return
            }
            const index = root.pubKeys.indexOf(contact.pubKey)
            const pubKeysCopy = Object.assign([], root.pubKeys)
            if (index === -1) {
                pubKeysCopy.push(contact.pubKey)
            } else {
                pubKeysCopy.splice(index, 1)
            }
            root.pubKeys = pubKeysCopy
        }
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: Theme.halfPadding
        Layout.rightMargin: Theme.halfPadding
    }

    StatusModalDivider {
        Layout.fillWidth: true
    }

    StatusDescriptionListItem {
        Layout.fillWidth: true
        title: qsTr("Share community")
        subTitle: Utils.getCommunityShareLink(root.communityId)
        tooltip.text: qsTr("Copied!")
        asset.name: "copy"
        iconButton.onClicked: {
            let link = Utils.getCommunityShareLink(root.communityId)
            ClipboardUtils.setText(link)
            tooltip.visible = !tooltip.visible
        }
    }
}
