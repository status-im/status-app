import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups

import utils
import AppLayouts.Wallet

import SortFilterProxyModel

import "../stores"

StatusMenu {
    id: root

    property AddAccountStore store

    property int itemsPerPage: 5

    signal selected(string address)

    QtObject {
        id: d

        property int currentPage: 0
        readonly property int lowerBound: root.itemsPerPage * d.currentPage
        readonly property int totalPages: Math.ceil(root.store.derivedAddressModel.count / root.itemsPerPage)
        readonly property bool revealNeedsPassword: root.store.addressRevealNeedsPassword
                                                    && !root.store.selectedOrigin.migratedToColdWallet
    }

    SortFilterProxyModel {
        id: proxyModel
        sourceModel: root.store.derivedAddressModel
        filters: IndexFilter {
            minimumIndex: d.lowerBound
            maximumIndex: d.lowerBound + root.itemsPerPage
        }
    }

    contentItem: Column {
        width: root.width

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            height: Constants.addAccountPopup.itemHeight - root.topPadding

            Row{
                anchors.centerIn: parent
                spacing: Theme.halfPadding

                StatusIcon {
                    visible: !root.store.addAccountModule.scanningForActivityIsOngoing ||
                             root.store.derivedAddressModel.loadedCount > 0
                    width: 20
                    height: 20
                    icon: "flash"
                    color: root.store.derivedAddressModel.loadedCount === 0?
                               Theme.palette.primaryColor1 : Theme.palette.successColor1
                }

                StatusLinkText {
                    visible: !root.store.addAccountModule.scanningForActivityIsOngoing
                    text: qsTr("Scan addresses for activity")
                    color: Theme.palette.primaryColor1
                    onClicked: {
                        root.store.startScanningForActivity()
                    }
                }

                StatusLoadingIndicator {
                    visible: root.store.addAccountModule.scanningForActivityIsOngoing &&
                             root.store.derivedAddressModel.loadedCount === 0
                }

                StatusBaseText {
                    visible: root.store.addAccountModule.scanningForActivityIsOngoing
                    color: root.store.derivedAddressModel.loadedCount === 0?
                               Theme.palette.baseColor1 : Theme.palette.successColor1
                    text: root.store.derivedAddressModel.loadedCount === 0?
                              qsTr("Scanning for activity...")
                            : qsTr("Activity fetched for %1 / %2 addresses").arg(root.store.derivedAddressModel.loadedCount).arg(root.store.derivedAddressModel.count)
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Theme.palette.baseColor2
            }
        }

        StatusListView {
            anchors.left: parent.left
            anchors.right: parent.right
            implicitHeight: contentHeight
            model: proxyModel

            delegate: Rectangle {
                objectName: "AddAccountPopup-GeneratedAddress-%1".arg(model.addressDetails.order)
                width: ListView.view.width
                height: Constants.addAccountPopup.itemHeight
                enabled: !model.addressDetails.alreadyCreated
                radius: Theme.halfPadding
                color: {
                    if (sensor.containsMouse) {
                        return Theme.palette.baseColor2
                    }
                    return "transparent"
                }

                StatusMouseArea {
                    id: sensor
                    anchors.fill: parent
                    hoverEnabled: parent.enabled
                    cursorShape: containsMouse ? Qt.PointingHandCursor : undefined
                    onClicked: {
                        root.selected(model.addressDetails.address)
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.padding
                    anchors.rightMargin: Theme.padding

                    StatusBaseText {
                        Layout.fillWidth: true
                        elide: Text.ElideMiddle
                        color: model.addressDetails.alreadyCreated ? Theme.palette.baseColor1 :
                                                                     Theme.palette.directColor1
                        text: WalletUtils.ownAddressToDisplay(model.addressDetails.address, d.revealNeedsPassword)
                    }

                    StatusIcon {
                        visible: model.addressDetails.detailsLoaded && model.addressDetails.hasActivity
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        icon: "flash"
                        color: Theme.palette.successColor1
                    }

                    StatusTextWithLoadingState {
                        text: {
                            if (!root.store.addAccountModule.scanningForActivityIsOngoing) {
                                return ""
                            }
                            if(model.addressDetails.detailsLoaded &&
                                    model.addressDetails.errorInScanningActivity) {
                                return qsTr("Activity unknown")
                            }
                            if (!model.addressDetails.detailsLoaded) {
                                return qsTr("loading...")
                            }
                            if (model.addressDetails.hasActivity) {
                                return qsTr("Has activity")
                            }
                            return qsTr("No activity")
                        }
                        color: {
                            if (!root.store.addAccountModule.scanningForActivityIsOngoing || !model.addressDetails.detailsLoaded) {
                                return "transparent"
                            }
                            if (model.addressDetails.hasActivity) {
                                return Theme.palette.successColor1
                            }
                            return Theme.palette.warningColor1
                        }
                        loading: root.store.addAccountModule.scanningForActivityIsOngoing && !model.addressDetails.detailsLoaded
                    }

                    StatusBaseText {
                        color: Theme.palette.baseColor1
                        text: model.addressDetails.order
                    }

                    StatusFlatRoundButton {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        type: StatusFlatRoundButton.Type.Tertiary
                        icon.name: "external"
                        icon.width: 16
                        icon.height: 16
                        onClicked: {
                            const link = "https://etherscan.io/address/%1".arg(model.addressDetails.address)
                            if (d.revealNeedsPassword)
                                Global.openOwnAddressLinkRequested(link)
                            else
                                Global.requestOpenLink(link)
                        }
                    }
                }
            }
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            height: Constants.addAccountPopup.itemHeight - root.bottomPadding

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: Theme.palette.baseColor2
            }

            StatusPageIndicator {
                objectName: "AddAccountPopup-GeneratedAddressesListPageIndicatior"
                anchors.top: parent.top
                anchors.topMargin: (Constants.addAccountPopup.itemHeight - height) * 0.5
                anchors.horizontalCenter: parent.horizontalCenter
                totalPages: d.totalPages

                onCurrentIndexChanged: {
                    d.currentPage = currentIndex
                }
            }
        }
    }
}
