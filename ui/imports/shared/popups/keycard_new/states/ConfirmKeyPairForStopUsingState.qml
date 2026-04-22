import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import utils

import "../helpers"

Control {
    id: root

    required property var keyPairItem

    required property string userProfileKeyUid
    required property string userProfilePubKey
    required property bool areTestNetworksEnabled

    property bool initialUnderstandChecked: false

    readonly property bool understandChecked: understandCheckBox.checked

    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding
    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding

    contentItem: ColumnLayout {
        spacing: Theme.padding

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        KeyPairItem {
            Layout.fillWidth: true
            visible: !!root.keyPairItem

            isKnownKeyPair: true

            userProfileKeyUid: root.userProfileKeyUid
            userProfileColor: Utils.colorForPubkey(Theme.palette, root.userProfilePubKey)

            keyPairKeyUid: root.keyPairItem ? root.keyPairItem.keyUid : ""
            keyPairMigratedToKeycard: !!root.keyPairItem && root.keyPairItem.migratedToKeycard
            keyPairName: root.keyPairItem ? root.keyPairItem.name : ""
            keyPairIcon: root.keyPairItem ? root.keyPairItem.icon : ""
            keyPairImage: root.keyPairItem ? root.keyPairItem.image : ""
            keyPairCardLocked: false
            areTestNetworksEnabled: root.areTestNetworksEnabled
            keyPairAccounts: root.keyPairItem ? root.keyPairItem.accounts : null
            keyPairLocation: root.keyPairItem ? Utils.getKeypairLocation(root.keyPairItem, false) : ""
            keyPairLocationColor: root.keyPairItem ? Utils.getKeypairLocationColor(Theme.palette, root.keyPairItem) : ""
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        StatusCheckBox {
            id: understandCheckBox
            Layout.fillWidth: true
            text: qsTr("I understand Keycard will no longer be used for signing, and Status password will be required")

            Component.onCompleted: {
                checked = root.initialUnderstandChecked
            }
        }
    }
}
