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

    property string initialSelectedKeyUid: ""
    property bool initialUnderstandChecked: false

    property string selectedKeyUid: initialSelectedKeyUid
    property string selectedKeyPairName: ""
    readonly property bool understandChecked: understandCheckBox.checked

    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding
    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding

    QtObject {
        id: d
        readonly property int profilePairTypeValue: Constants.keycard.keyPairType.profile
    }

    contentItem: ColumnLayout {
        spacing: Theme.padding

        StatusBaseText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: qsTr("Select key pair")
            color: Theme.palette.baseColor1
        }

        ButtonGroup {
            id: keyPairsButtonGroup
        }

        SortFilterProxyModel {
            id: filteredModel
            sourceModel: root.keypairsModel ?? null
            filters: ExpressionFilter {
                expression: model.keyPair.pairType !== d.profilePairTypeValue
                            && !model.keyPair.migratedToKeycard
            }
        }

        ListView {
            id: keypairsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Theme.halfPadding
            model: filteredModel

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            delegate: KeyPairCompactItem {
                width: keypairsList.width - (keypairsList.ScrollBar.vertical.visible
                                             ? keypairsList.ScrollBar.vertical.width : 0)

                usedAsSelectOption: true
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
            Layout.preferredHeight: Theme.padding
        }

        StatusCheckBox {
            id: understandCheckBox
            Layout.fillWidth: true
            text: qsTr("I understand that moving this key pair will require using Keycard to sign")

            Component.onCompleted: {
                checked = root.initialUnderstandChecked
            }
        }
    }
}
