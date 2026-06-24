import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Theme

import utils
import shared.popups.keypairimport.helpers

import SortFilterProxyModel

ColumnLayout {
    id: root

    required property string componentUid
    required property bool isEditMode
    property var keypairSigningModel

    required property var selectedSharedAddressesMap // Map[address, [keyUid, selected, isAirdrop]
    required property int totalNumOfAddressesForSharing

    required property string communityName
    readonly property string title: root.isEditMode?
                                        qsTr("Save addresses you share with %1").arg(root.communityName)
                                      : qsTr("Request to join %1").arg(root.communityName)
    readonly property var rightButtons: [d.rightBtn]

    signal joinCommunity()
    signal signSharedAddressesForKeypair(string keyUid)

    function allSigned() {
        d.allSigned = true
    }

    QtObject {
        id: d

        readonly property int selectedSharedAddressesCount: root.selectedSharedAddressesMap.size

        property bool allSigned: false

        readonly property var rightBtn: StatusButton {
            objectName: "membershipSubmitSharedAddressesButton"
            enabled: d.allSigned
            text: {
                if (d.selectedSharedAddressesCount === root.totalNumOfAddressesForSharing) {
                    return qsTr("Share all addresses to join")
                }
                return qsTr("Share %n address(s) to join", "", d.selectedSharedAddressesCount)
            }
            onClicked: {
                root.joinCommunity()
            }
        }
    }

    Component {
        id: keypairDelegate

        KeyPairItem {
            id: kpDelegate
            width: ListView.view.width
            sensor.hoverEnabled: !model.keyPair.ownershipVerified
            additionalInfoForProfileKeypair: ""

            keyPairType: model.keyPair.pairType
            keyPairKeyUid: model.keyPair.keyUid
            keyPairName: model.keyPair.name
            keyPairIcon: model.keyPair.icon
            keyPairImage: model.keyPair.image
            keyPairDerivedFrom: model.keyPair.derivedFrom
            keyPairAccounts: model.keyPair.accounts

            readonly property bool migratedToColdWallet: model.keyPair.migratedToColdWallet

            components: [
                StatusButton {
                    objectName: "signKeyPairButton"
                    text: qsTr("Sign")
                    visible: !model.keyPair.ownershipVerified
                    icon.name: {
                        if (userProfile.keyUid !== kpDelegate.keyPairKeyUid && kpDelegate.migratedToColdWallet)
                            return "keycard"
                        if (userProfile.usingBiometricLogin)
                            return "touch-id"
                        if (userProfile.migratedToColdWallet)
                            return "keycard"
                        return "password"
                    }

                    onClicked: {
                        root.signSharedAddressesForKeypair(model.keyPair.keyUid)
                    }
                },
                StatusButton {
                    text: qsTr("Signed")
                    visible: model.keyPair.ownershipVerified
                    enabled: false
                    normalColor: "transparent"
                    disabledColor: "transparent"
                    disabledTextColor: Theme.palette.successColor1
                    icon.name: "checkmark-circle"
                }
            ]

            SequentialAnimation {
                running: model.keyPair.ownershipVerified
                PropertyAnimation {
                    target: kpDelegate
                    property: "color"
                    to: Theme.palette.successColor3
                    duration: 500
                }
                PropertyAnimation {
                    target: kpDelegate
                    property: "color"
                    to: Theme.palette.baseColor2
                    duration: 1500
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: Theme.xlPadding

        spacing: Theme.padding

        StatusBaseText {
            Layout.preferredWidth: parent.width
            elide: Text.ElideRight
            text: qsTr("To share %n address(s) with <b>%1</b>, sign with the associated key pairs...", "", d.selectedSharedAddressesCount).arg(root.communityName)
        }

        RowLayout {
            Layout.fillWidth: true
            visible: storedOnDeviceList.visible

            StatusBaseText {
                Layout.fillWidth: true
                text: qsTr("Stored on device")
                color: Theme.palette.baseColor1
                wrapMode: Text.WordWrap
            }
        }

        StatusListView {
            id: storedOnDeviceList
            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight
            visible: count > 0
            spacing: Theme.padding
            model: SortFilterProxyModel {
                sourceModel: root.keypairSigningModel
                filters: ExpressionFilter {
                    expression: !model.keyPair.migratedToColdWallet
                }
            }
            delegate: keypairDelegate
        }

        Item {
            visible: storedOnDeviceList.visible && storedOnKeycardList.visible
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.xlPadding
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: storedOnKeycardList.visible

            StatusBaseText {
                text: qsTr("Stored on keycard")
                color: Theme.palette.baseColor1
                wrapMode: Text.WordWrap
            }

            StatusIcon {
                Layout.preferredHeight: 20
                Layout.preferredWidth: 20
                color: Theme.palette.baseColor1
                icon: "keycard"
            }
        }

        StatusListView {
            id: storedOnKeycardList
            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight
            visible: count > 0
            spacing: Theme.padding
            model: SortFilterProxyModel {
                sourceModel: root.keypairSigningModel
                filters: ExpressionFilter {
                    expression: model.keyPair.migratedToColdWallet
                }
            }
            delegate: keypairDelegate
        }
    }
}
