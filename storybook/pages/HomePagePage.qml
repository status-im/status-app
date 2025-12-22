import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Components

import Models
import Storybook

import utils

import AppLayouts.HomePage
import AppLayouts.Profile.stores as ProfileStores

SplitView {
    id: root

    orientation: Qt.Vertical

    Logs { id: logs }

    HomePage {
        id: homePage
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        HomePageAdaptor {
            id: homePageAdaptor

            sectionsBaseModel: SectionsModel {}
            chatsBaseModel: ChatsModel {}
            chatsSearchBaseModel: ChatsSearchModel {}
            walletsBaseModel: WalletAccountsModel {}
            dappsBaseModel: DappsModel {}

            showCommunities: ctrlShowCommunities.checked || ctrlShowAllEntries.checked
            showSettings: ctrlShowSettings.checked || ctrlShowAllEntries.checked
            showChats: ctrlShowChats.checked || ctrlShowAllEntries.checked
            showAllChats: ctrlShowAllChats.checked || ctrlShowAllEntries.checked
            showWallets: ctrlShowWallets.checked || ctrlShowAllEntries.checked
            showDapps: ctrlShowDapps.checked || ctrlShowAllEntries.checked

            showEnabledSectionsOnly: ctrlShowEnabledSectionsOnly.checked
            marketEnabled: ctrlMarketEnabled.checked
            browserEnabled: ctrlBrowserEnabled.checked
            keycardEnabled: ctrlKeycardEnabled.checked

            syncingBadgeCount: 2
            messagingBadgeCount: 4
            showBackUpSeed: true
            backUpSeedBadgeCount: 1

            searchPhrase: homePage.searchPhrase

            profileId: "0xdeadbeef"
        }

        homePageEntriesModel: homePageAdaptor.homePageEntriesModel
        sectionsModel: homePageAdaptor.sectionsModel
        pinnedModel: homePageAdaptor.pinnedModel

        onItemActivated: function(key, sectionType, itemId) {
            homePageAdaptor.setTimestamp(key, new Date().valueOf())
            logs.logEvent("onItemActivated", ["key", "sectionType", "itemId"], arguments)
            console.info("!!! ITEM ACTIVATED; key:", key, "; sectionType:", sectionType, "; itemId:", itemId)
        }
        onItemPinRequested: function(key, pin) {
            homePageAdaptor.setPinned(key, pin)
            if (pin)
                homePageAdaptor.setTimestamp(key, new Date().valueOf()) // update the timestamp so that the pinned dock items are sorted by their recency
            logs.logEvent("onItemPinRequested", ["key", "pin"], arguments)
            console.info("!!! ITEM", key, "PINNED:", pin)
        }
        onDappDisconnectRequested: function(dappUrl) {
            logs.logEvent("onDappDisconnectRequested", ["dappUrl"], arguments)
            console.info("!!! DAPP DISCONNECT:", dappUrl)
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 320
        SplitView.preferredHeight: 320
        SplitView.fillWidth: true

        logsView.logText: logs.logText

        ColumnLayout {
            Switch {
                id: ctrlShowEnabledSectionsOnly
                text: "Show enabled sections only"
            }
            Switch {
                id: ctrlMarketEnabled
                text: "Market enabled"
                checked: true
            }
            Switch {
                id: ctrlBrowserEnabled
                text: "Browser enabled"
                checked: true
            }
            Switch {
                id: ctrlKeycardEnabled
                text: "Keycard enabled"
                checked: true
            }
            RowLayout {
                Switch {
                    id: ctrlShowAllEntries
                    text: "Show all entries"
                    checked: true
                }
                Switch {
                    id: ctrlShowCommunities
                    text: "Show Communities"
                    checked: true
                    enabled: !ctrlShowAllEntries.checked
                }
                Switch {
                    id: ctrlShowChats
                    text: "Show Chats"
                    checked: true
                    enabled: !ctrlShowAllEntries.checked
                }
                Switch {
                    id: ctrlShowAllChats
                    text: "Show All Chats"
                    checked: true
                    enabled: ctrlShowChats.checked && !ctrlShowAllEntries.checked
                }
                Switch {
                    id: ctrlShowWallets
                    text: "Show Wallets"
                    checked: true
                    enabled: !ctrlShowAllEntries.checked
                }
                Switch {
                    id: ctrlShowSettings
                    text: "Show Settings"
                    checked: true
                    enabled: !ctrlShowAllEntries.checked
                }
                Switch {
                    id: ctrlShowDapps
                    text: "Show dApps"
                    checked: true
                    enabled: !ctrlShowAllEntries.checked
                }
            }
            Button {
                text: "Reset"
                onClicked: homePageAdaptor.clear()
            }
        }
    }
}

// category: Sections
// status: good
// https://www.figma.com/design/uXJKlC0LaUjvwL5MEsI9v4/Shell----Desktop?node-id=251-357756&m=dev
