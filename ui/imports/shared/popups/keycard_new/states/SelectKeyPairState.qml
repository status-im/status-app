import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components

import SortFilterProxyModel

import utils

import "../helpers"

Control {
    id: root

    required property var keypairsModel

    required property string userProfilePublicKey

    property bool profileOnly: false
    property string fixedKeyUid: ""
    property string initialSelectedKeyUid: ""
    property bool initialUnderstandChecked: false

    readonly property bool singleKeyPairMode: root.profileOnly || root.fixedKeyUid.length > 0

    property string selectedKeyUid: initialSelectedKeyUid
    property string selectedKeyPairName: ""
    readonly property bool understandChecked: understandCheckBox.checked

    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding
    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding

    QtObject {
        id: d
        readonly property int profileKeyPairTypeValue: Constants.keycard.keyPairType.profile
        readonly property int seedKeyPairTypeValue: Constants.keycard.keyPairType.seedImport
    }

    contentItem: ColumnLayout {
        spacing: Theme.padding

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.singleKeyPairMode
        }

        StatusBaseText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: root.profileOnly ? qsTr("Profile key pair")
                                   : root.fixedKeyUid.length > 0
                                     ? qsTr("Key pair")
                                     : qsTr("Select key pair")
            color: Theme.palette.baseColor1
        }

        ButtonGroup {
            id: keyPairsButtonGroup
        }

        SortFilterProxyModel {
            id: filteredModel
            sourceModel: root.keypairsModel ?? null
            filters: ExpressionFilter {
                expression: root.profileOnly
                            ? model.keyPair.pairType === d.profileKeyPairTypeValue && !model.keyPair.migratedToColdWallet
                            : root.fixedKeyUid.length > 0
                              ? model.keyPair.keyUid === root.fixedKeyUid && !model.keyPair.migratedToColdWallet
                              : model.keyPair.pairType === d.seedKeyPairTypeValue && !model.keyPair.migratedToColdWallet
            }
        }

        ListView {
            id: keypairsList
            Layout.fillWidth: true
            Layout.fillHeight: !root.singleKeyPairMode
            Layout.preferredHeight: root.singleKeyPairMode ? contentHeight : -1
            clip: true
            spacing: Theme.halfPadding
            model: filteredModel

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            delegate: KeyPairCompactItem {
                width: keypairsList.width - (keypairsList.ScrollBar.vertical.visible
                                             ? keypairsList.ScrollBar.vertical.width : 0)

                userProfilePublicKey: root.userProfilePublicKey

                usedAsSelectOption: !root.singleKeyPairMode
                buttonGroup: keyPairsButtonGroup
                checked: model.keyPair.keyUid === root.initialSelectedKeyUid

                keyPairType: model.keyPair.pairType
                keyPairName: model.keyPair.name
                keyPairIcon: model.keyPair.icon
                keyPairImage: model.keyPair.image
                keyPairCardLocked: model.keyPair.locked
                keyPairAccounts: model.keyPair.accounts

                onKeyPairSelected: {
                    root.selectedKeyUid = model.keyPair.keyUid
                    root.selectedKeyPairName = model.keyPair.name
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.singleKeyPairMode
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.padding
        }

        StatusCheckBox {
            id: understandCheckBox
            Layout.fillWidth: true
            text: root.profileOnly
                  ? qsTr("I understand that moving this key pair will require using Keycard to log in and sign")
                  : qsTr("I understand that moving this key pair will require using Keycard to sign")

            Component.onCompleted: {
                checked = root.initialUnderstandChecked
            }
        }
    }
}
