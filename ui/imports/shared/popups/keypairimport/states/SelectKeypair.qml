import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Components
import StatusQ.Core.Theme

import shared.popups.keypairimport.helpers
import shared.status

import utils

import SortFilterProxyModel

import "../stores"

Item {
    id: root

    property KeypairImportStore store

    implicitHeight: layout.implicitHeight

    QtObject {
        id: d

        readonly property string fullyOperableValue: Constants.keypair.operability.fullyOperable
        readonly property string partiallyOperableValue: Constants.keypair.operability.partiallyOperable
        readonly property string profileTypeValue: Constants.keypair.type.profile
        readonly property int margin: 16

        function importKeypairs() {
            root.store.currentState.doSecondaryAction()
        }
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        StatusBaseText {
            Layout.fillWidth: true
            Layout.leftMargin: d.margin
            Layout.rightMargin: d.margin
            text: qsTr("To use the associated accounts on this device, you need to import their key pairs.")
            wrapMode: Text.WordWrap
        }

        StatusSectionHeadline {
            Layout.fillWidth: true
            Layout.leftMargin: d.margin
            Layout.rightMargin: d.margin
            text: qsTr("Import key pairs from your other device")
        }

        StatusListItem {
            title: qsTr("Import via scanning encrypted QR")
            asset {
                width: 24
                height: 24
                name: "qr"
            }

            onClicked: {
                d.importKeypairs()
            }

            components: [
                StatusIcon {
                    icon: "next"
                    color: Theme.palette.baseColor1
                    StatusMouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            d.importKeypairs()
                        }
                    }
                }
            ]

        }

        StatusSectionHeadline {
            Layout.fillWidth: true
            Layout.leftMargin: d.margin
            Layout.rightMargin: d.margin
            text: qsTr("Import individual keys")
        }

        KeyPairList {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignLeft

            disableSelectionForKeypairsWithNonDefaultDerivationPath: false
            displayRadioButtonForSelection: false
            useTransparentItemBackgroundColor: true

            modelFilters: ExpressionFilter {
                expression: model.keyPair.migratedToColdWallet ||
                            model.keyPair.pairType == d.profileTypeValue  ||
                            model.keyPair.operability == d.fullyOperableValue ||
                            model.keyPair.operability == d.partiallyOperableValue
                inverted: true
            }
            keyPairModel: root.store.keypairImportModule.keypairModel

            onKeyPairSelected: {
                root.store.keypairImportModule.setSelectedKeyPair(keyUid)
                root.store.currentState.doPrimaryAction()
            }
        }
    }
}
