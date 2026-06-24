import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import utils

import "../stores"

Column {
    id: root

    property AddAccountStore store

    padding: Theme.padding
    state: {
        if (root.store.editMode) {
            return d.expandedState
        }

        root.store.addAccountModule.actionAuthenticated? d.expandedState : d.collapsedState
    }

    QtObject {
        id: d

        readonly property string expandedState: "expanded"
        readonly property string collapsedState: "collapsed"
    }

    RowLayout {
        width: parent.width - 2 * root.padding
        height: 64
        visible: !root.store.editMode

        StatusBaseText {
            textFormat: Text.RichText
            text: {
                let t = qsTr("Derivation path")
                let t1 = qsTr("(advanced)")
                return `%1 <font color="${Theme.palette.baseColor1}">%2</font>`.arg(t).arg(t1)
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
        }

        StatusButton {
            objectName: "AddAccountPopup-EditDerivationPath"
            visible: !root.store.addAccountModule.actionAuthenticated
            text: qsTr("Edit")

            icon.name: Utils.resolveAuthSignIcon(root.store.selectedOrigin.keyUid,
                                                 root.store.selectedOrigin.migratedToColdWallet,
                                                 Constants.AuthSignPurpose.AddAccountCustomPath
                                                 )

            onClicked: {
                root.store.authenticateForEditingDerivationPath()
            }
        }

        StatusIcon {
            id: expandImage
            visible: root.store.addAccountModule.actionAuthenticated
            color: Theme.palette.baseColor1

            StatusMouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.state === d.expandedState) {
                        root.state = d.collapsedState
                        return
                    }
                    root.state = d.expandedState

                    root.state = Qt.binding(function(){ return root.store.addAccountModule.actionAuthenticated? d.expandedState : d.collapsedState })
                }
            }
        }
    }

    DerivationPath {
        id: derivationPathContent
        visible: !root.store.editMode
        width: parent.width - 2 * root.padding

        store: root.store
    }

    Loader {
        width: parent.width - 2 * root.padding
        active: root.store.editMode
        sourceComponent: DerivationPathDisplay {
            store: root.store
        }
    }

    states: [
        State {
            name: d.expandedState
            PropertyChanges {target: expandImage; icon: "chevron-up"}
            PropertyChanges {target: derivationPathContent; visible: !root.store.editMode}
        },
        State {
            name: d.collapsedState
            PropertyChanges {target: expandImage; icon: "chevron-down"}
            PropertyChanges {target: derivationPathContent; visible: false}
        }
    ]

    transitions: [
        Transition {
            from: d.collapsedState
            to: d.expandedState
            NumberAnimation { properties: "height"; duration: 200;}
        },
        Transition {
            from: d.expandedState
            to: d.collapsedState
            NumberAnimation { properties: "height"; duration: 200;}
        }
    ]
}
