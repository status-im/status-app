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
    signal signProfileKeypairAndAllNonKeycardKeypairs()
    signal signSharedAddressesForKeypair(string keyUid)

    function allSigned() {
        d.allSigned = true
    }

    QtObject {
        id: d

        readonly property int selectedSharedAddressesCount: root.selectedSharedAddressesMap.size

        property bool allSigned: false

        readonly property bool anyOfSelectedAddressesToRevealBelongToProfileKeypair: {
            for (const [key, value] of root.selectedSharedAddressesMap) {
                if (value.keyUid === userProfile.keyUid) {
                    return true
                }
            }
            return false
        }

        readonly property bool thereAreMoreThanOneNonProfileRegularKeypairs: nonProfileRegularKeypairs.count > 1

        readonly property bool allNonProfileRegularKeypairsSigned: {
            for (let i = 0; i < nonProfileRegularKeypairs.model.count; ++i) {
                const item = nonProfileRegularKeypairs.model.get(i)
                if (!!item && !item.keyPair.ownershipVerified) {
                    return false
                }
            }
            return true
        }

        readonly property var rightBtn: StatusButton {
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

    ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: Theme.xlPadding

        spacing: Theme.padding

        StatusBaseText {
            Layout.preferredWidth: parent.width
            elide: Text.ElideRight
            text: qsTr("To share %n address(s) with <b>%1</b>, authenticate the associated key pairs...", "", d.selectedSharedAddressesCount).arg(root.communityName)
        }

        RowLayout {
            Layout.fillWidth: true

            visible: nonKeycardProfileKeypair.visible

            StatusBaseText {
                Layout.fillWidth: true
                text: qsTr("Stored on device")
                wrapMode: Text.WordWrap
            }
        }

        StatusListView {
            id: nonKeycardProfileKeypair
            Layout.fillWidth: true
            Layout.preferredHeight: nonKeycardProfileKeypair.contentHeight
            visible: nonKeycardProfileKeypair.model.count > 0
            spacing: Theme.padding
            model: SortFilterProxyModel {
                sourceModel: root.keypairSigningModel
                filters: ExpressionFilter {
                    expression: model.keyPair.keyUid === userProfile.keyUid && !userProfile.migratedToColdWallet
                }
            }
            delegate: KeyPairItem {
                id: kpOnDeviceDelegate
                width: ListView.view.width
                sensor.hoverEnabled: false
                additionalInfoForProfileKeypair: ""

                keyPairType: model.keyPair.pairType
                keyPairKeyUid: model.keyPair.keyUid
                keyPairName: model.keyPair.name
                keyPairIcon: model.keyPair.icon
                keyPairImage: model.keyPair.image
                keyPairDerivedFrom: model.keyPair.derivedFrom
                keyPairAccounts: model.keyPair.accounts

                components: [
                    StatusButton {
                        text: qsTr("Authenticate")
                        visible: !model.keyPair.ownershipVerified
                        icon.name: {
                            if (userProfile.usingBiometricLogin) {
                                return "touch-id"
                            }

                            if (userProfile.migratedToColdWallet) {
                                return "keycard"
                            }

                            return "password"
                        }

                        onClicked: {
                            root.signProfileKeypairAndAllNonKeycardKeypairs()
                        }
                    },
                    StatusButton {
                        text: qsTr("Authenticated")
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
                        target: kpOnDeviceDelegate
                        property: "color"
                        to: Theme.palette.successColor3
                        duration: 500
                    }
                    PropertyAnimation {
                        target: kpOnDeviceDelegate
                        property: "color"
                        to: Theme.palette.baseColor2
                        duration: 1500
                    }
                }
            }
        }

        Item {
            visible: nonKeycardProfileKeypair.visible
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.xlPadding
        }

        RowLayout {
            Layout.fillWidth: true

            visible: keycardKeypairs.visible

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
            id: keycardKeypairs
            Layout.fillWidth: true
            Layout.preferredHeight: keycardKeypairs.contentHeight
            visible: keycardKeypairs.model.count > 0
            spacing: Theme.padding
            model: SortFilterProxyModel {
                sourceModel: root.keypairSigningModel
                filters: ExpressionFilter {
                    expression: model.keyPair.migratedToColdWallet
                }
            }
            delegate: KeyPairItem {
                id: kpOnKeycardDelegate
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

                components: [
                    StatusButton {
                        text: qsTr("Authenticate")
                        visible: !model.keyPair.ownershipVerified
                        icon.name: "keycard"

                        onClicked: {
                            if (model.keyPair.keyUid === userProfile.keyUid) {
                                root.signProfileKeypairAndAllNonKeycardKeypairs()
                                return
                            }
                            root.signSharedAddressesForKeypair(model.keyPair.keyUid)
                        }
                    },
                    StatusButton {
                        text: qsTr("Authenticated")
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
                        target: kpOnKeycardDelegate
                        property: "color"
                        to: Theme.palette.successColor3
                        duration: 500
                    }
                    PropertyAnimation {
                        target: kpOnKeycardDelegate
                        property: "color"
                        to: Theme.palette.baseColor2
                        duration: 1500
                    }
                }
            }
        }

        Item {
            visible: keycardKeypairs.visible
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.xlPadding
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: nonProfileRegularKeypairs.visible

            StatusBaseText {
                Layout.preferredWidth: !d.anyOfSelectedAddressesToRevealBelongToProfileKeypair &&
                                       d.thereAreMoreThanOneNonProfileRegularKeypairs?
                                           370
                                         : -1
                Layout.fillWidth: true
                text: !d.anyOfSelectedAddressesToRevealBelongToProfileKeypair &&
                      d.thereAreMoreThanOneNonProfileRegularKeypairs?
                          qsTr("Authenticate via “%1” key pair").arg(userProfile.name)
                        : qsTr("The following key pairs will be authenticated via “%1” key pair").arg(userProfile.name)
                color: Theme.palette.baseColor1
                wrapMode: Text.WrapAnywhere
            }

            StatusButton {
                Layout.rightMargin: 16
                text: qsTr("Authenticate")
                visible: !d.anyOfSelectedAddressesToRevealBelongToProfileKeypair
                         && d.thereAreMoreThanOneNonProfileRegularKeypairs
                         && !d.allNonProfileRegularKeypairsSigned
                icon.name: {
                    if (userProfile.usingBiometricLogin) {
                        return "touch-id"
                    }

                    if (userProfile.migratedToColdWallet) {
                        return "keycard"
                    }

                    return "password"
                }

                onClicked: {
                    root.signProfileKeypairAndAllNonKeycardKeypairs()
                }
            }
        }

        StatusListView {
            id: nonProfileRegularKeypairs
            Layout.fillWidth: true
            Layout.preferredHeight: nonProfileRegularKeypairs.contentHeight
            visible: nonProfileRegularKeypairs.model.count > 0
            spacing: Theme.padding
            model: SortFilterProxyModel {
                sourceModel: root.keypairSigningModel
                filters: ExpressionFilter {
                    expression: !model.keyPair.migratedToColdWallet && model.keyPair.keyUid !== userProfile.keyUid
                }
            }
            delegate: KeyPairItem {
                id: dependantKpOnDeviceDelegate
                width: ListView.view.width
                sensor.hoverEnabled: false
                additionalInfoForProfileKeypair: ""

                keyPairType: model.keyPair.pairType
                keyPairKeyUid: model.keyPair.keyUid
                keyPairName: model.keyPair.name
                keyPairIcon: model.keyPair.icon
                keyPairImage: model.keyPair.image
                keyPairDerivedFrom: model.keyPair.derivedFrom
                keyPairAccounts: model.keyPair.accounts

                components: [
                    StatusButton {
                        Layout.rightMargin: 16
                        text: qsTr("Authenticate")
                        visible: !d.anyOfSelectedAddressesToRevealBelongToProfileKeypair
                                 && !d.thereAreMoreThanOneNonProfileRegularKeypairs
                                 && !model.keyPair.ownershipVerified
                        icon.name: {
                            if (userProfile.usingBiometricLogin) {
                                return "touch-id"
                            }

                            if (userProfile.migratedToColdWallet) {
                                return "keycard"
                            }

                            return "password"
                        }

                        onClicked: {
                            root.signProfileKeypairAndAllNonKeycardKeypairs()
                        }
                    },
                    StatusButton {
                        text: qsTr("Authenticated")
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
                        target: dependantKpOnDeviceDelegate
                        property: "color"
                        to: Theme.palette.successColor3
                        duration: 500
                    }
                    PropertyAnimation {
                        target: dependantKpOnDeviceDelegate
                        property: "color"
                        to: Theme.palette.baseColor2
                        duration: 1500
                    }
                }
            }
        }
    }
}
