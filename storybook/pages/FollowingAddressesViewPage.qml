import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import AppLayouts.Wallet.views
import AppLayouts.Wallet.stores as WalletStores
import shared.stores as SharedStores

import Models
import Storybook
import utils

// Drives the real FollowingAddressesView through the real wallet RootStore. The
// pages come from WalletSectionMock's generated profile, served through
// walletSectionFollowingAddresses.fetchFollowingAddresses (limit/offset/search),
// so pagination and search exercise the production path.
SplitView {
    id: root

    Logs { id: logs }

    WalletSectionMock {
        id: walletMock

        // Accounts only: the header's account selector needs them, and the store
        // derives the "user address" of the fetch from the first one.
        accountCount: 3
        assetGroupCount: 0
        collectibleCount: 0
        communityCount: 0
        savedAddressCount: 0
        followingAddressCount: ctrlTotal.value
    }

    Connections {
        target: walletSectionFollowingAddresses
        function onFetchRequested(userAddress, search, limit, offset) {
            logs.logEvent("fetch: address=%1 search='%2' limit=%3 offset=%4"
                          .arg(Utils.compactAddress(userAddress, 4)).arg(search)
                          .arg(limit).arg(offset))
        }
    }

    Rectangle {
        SplitView.fillWidth: true
        SplitView.fillHeight: true
        color: Theme.palette.baseColor3

        FollowingAddressesView {
            anchors.fill: parent

            rootStore: WalletStores.RootStore
            contactsStore: SharedStores.ContactsStore
            networkConnectionStore: SharedStores.NetworkConnectionStore {}
            networksStore: SharedStores.NetworksStore {}

            onSendToAddressRequested: (address) => logs.logEvent("sendToAddressRequested: " + address)
        }
    }

    Pane {
        SplitView.minimumWidth: 320
        SplitView.preferredWidth: 320

        ColumnLayout {
            anchors.fill: parent
            spacing: 16

            RowLayout {
                Label { text: "Following addresses:" }
                SpinBox {
                    id: ctrlTotal
                    objectName: "followingAddressesTotalSpinBox"
                    from: 0
                    to: 1000
                    stepSize: 5
                    value: 25
                    editable: true
                }
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Total reported by the backend: %1\nCurrent page rows: %2"
                      .arg(walletSectionFollowingAddresses.totalFollowingCount)
                      .arg(walletSectionFollowingAddresses.model.count)
            }

            Button {
                Layout.fillWidth: true
                text: "Reinstall profile"
                onClicked: root.reinstall()
            }

            LogsView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                logText: logs.logText
            }
        }
    }

    function reinstall() {
        walletMock.uninstall()
        walletMock.install()
        WalletStores.RootStore.refreshFollowingAddresses("", "", 10, 0)
    }

    Component.onCompleted: {
        WalletStores.RootStore.palette = Theme.palette
        reinstall()
    }

    Component.onDestruction: walletMock.uninstall()

    Connections {
        target: walletMock
        function onFollowingAddressCountChanged() { root.reinstall() }
    }
}

// category: Views
// status: good
