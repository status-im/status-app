import QtCore
import QtQuick

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils

import QtModelsToolkit
import SortFilterProxyModel

import utils

import AppLayouts.Profile.helpers

QObject {
    id: root

    // for HomePage grid entries
    required property var sectionsBaseModel
    required property var chatsBaseModel
    property var chatsSearchBaseModel
    required property var walletsBaseModel
    required property var dappsBaseModel

    required property string searchPhrase

    // for Settings
    required property int syncingBadgeCount
    required property int messagingBadgeCount
    required property bool showBackUpSeed
    required property int backUpSeedBadgeCount
    required property bool keycardEnabled

    // internal settings
    required property string profileId
    property bool showEnabledSectionsOnly
    property bool marketEnabled: true
    property bool browserEnabled: true

    property bool showCommunities: true
    property bool showSettings: true
    property bool showChats: true
    property bool showAllChats: false // from the chat_search_model
    property bool showWallets: true
    property bool showDapps: true

    /**
      Provided models structure:

      Common data:
        key                 [string] - unique identifier of a section across all models, e.g "1;0x3234235"
        id                  [string] - id of this section
        sectionType         [int]    - type of this section (Constants.appSection.*)
        name                [string] - section's name, e.g. "Chat" or "Wallet" or a community name
        icon                [string] - section's icon (url like or blob)
        color               [color]  - the section's color
        banner              [string] - the section's banner image (url like or blob), mostly empty for non-communities
        hasNotification     [bool]   - whether the section has any notification (w/o denoting the number)
        notificationsCount  [int]    - number of notifications, if any
        enabled             [bool]   - whether the section should show in the UI

      Communities:
        members             [int]   - number of members
        activeMembers       [int]   - number of active members
        pending             [bool]  - whether a request to join/spectate is in effect
        banned              [bool]  - whether we are kicked/banned from this community

      Chats:
        chatType            [int]   - type of the chat (Constants.chatType.*)
        onlineStatus        [int]   - online status of the contact (Constants.onlineStatus.*)

      Wallets:
        walletType          [string] - type of the wallet (Constants.*WalletType)
        currencyBalance     [string] - user formatted balance of the wallet in fiat (e.g. "1 000,23 CZK")

      Dapps:
        connectorBadge      [string] - decoration image for the connector used

      Settings:
        isExperimental      [bool]   - whether the section is experimental (shows the Beta badge)

      Writable layer:
        pinned             [bool]   - whether the item is pinned in the UI
        timestamp          [int]    - timestamp of the last user interaction with the item
    **/

    readonly property var homePageEntriesModel: d.homePageEntriesModel
    Component.onCompleted: {
        Qt.callLater(function() {
            d.homePageEntriesModel = filteredCombinedModel // FIXME bug in SFPM or OPM
            root.load()
        })
    }

    Component.onDestruction: save()

    QtObject {
        id: d
        property var homePageEntriesModel
    }

    // Provides data for the Dock's left (fixed) part; w/o the writable layer
    readonly property var sectionsModel: SortFilterProxyModel {
        sourceModel: root.sectionsBaseModel
        filters: [
            ValueFilter {
                roleName: "sectionType"
                value: Constants.appSection.homePage
                inverted: true
            },
            ValueFilter {
                roleName: "sectionType"
                value: Constants.appSection.loadingSection
                inverted: true
            },
            ValueFilter {
                roleName: "sectionType"
                value: Constants.appSection.community
                inverted: true
            },
            ValueFilter {
                roleName: "sectionType"
                value: Constants.appSection.browser
                enabled: !root.browserEnabled
                inverted: true
            },
            ValueFilter {
                roleName: "sectionType"
                value: Constants.appSection.swap
                enabled: root.marketEnabled
                inverted: true
            },
            ValueFilter {
                roleName: "sectionType"
                value: Constants.appSection.market
                enabled: !root.marketEnabled
                inverted: true
            },
            ValueFilter {
                roleName: "enabled"
                value: true
                enabled: root.showEnabledSectionsOnly
            }
        ]
        sorters: [
            FilterSorter {
                ValueFilter { roleName: "sectionType"; value: Constants.appSection.profile; inverted: true } // Settings last
            },
            RoleSorter { roleName: "sectionType" }
        ]
    }

    // Provides data for the Dock's right (variable/pinned) part
    readonly property var pinnedModel: SortFilterProxyModel {
        sourceModel: homePageProxyModel
        filters: [
            ValueFilter {
                roleName: "pinned"
                value: true
            }
        ]
        sorters: [
            RoleSorter {
                roleName: "timestamp"
            }
        ]
    }

    function clear() {
        const count = homePageProxyModel.ModelCount.count
        for (let i = 0; i < count; i++) {
            homePageProxyModel.proxyObject(i).pinned = false
            homePageProxyModel.proxyObject(i).timestamp = 0
        }
    }

    ObjectProxyModel {
        id: communitiesModel

        sourceModel: SortFilterProxyModel {
            sourceModel: root.sectionsBaseModel
            filters: [
                ValueFilter {
                    roleName: "sectionType"
                    value: Constants.appSection.community
                }
            ]
        }

        delegate: QtObject {
            readonly property string key: Constants.appSection.community + ';' + model.id
            readonly property string id: model.id
            readonly property string name: model.name
            readonly property string icon: model.image
            readonly property color color: model.color
            readonly property string banner: model.bannerImageData
            readonly property bool hasNotification: model.hasNotification
            readonly property int notificationsCount: model.notificationsCount

            readonly property int members: model.joinedMembersCount
            readonly property int activeMembers: model.activeMembersCount

            readonly property bool pending: model.spectated && !model.joined
            readonly property bool banned: model.amIBanned
        }

        expectedRoles: ["id", "name", "image", "color", "bannerImageData", "hasNotification", "notificationsCount",
            "joinedMembersCount", "activeMembersCount", "spectated", "joined", "amIBanned"]
        exposedRoles: ["key", "id", "name", "icon", "color", "banner", "hasNotification", "notificationsCount",
            "members", "activeMembers", "pending", "banned"]
    }

    ObjectProxyModel {
        id: settingsModel

        sourceModel: SettingsEntriesModel {
            showWalletEntries: true
            showBrowserEntries: root.browserEnabled
            syncingBadgeCount: root.syncingBadgeCount
            messagingBadgeCount: root.messagingBadgeCount
            showBackUpSeed: root.showBackUpSeed
            backUpSeedBadgeCount: root.backUpSeedBadgeCount
            isKeycardEnabled: root.keycardEnabled
            showSubSubSections: true
        }
        delegate: QtObject {
            readonly property string key: Constants.appSection.profile + ';' + model.subsection
            readonly property string id: model.subsection
            readonly property string name: model.text
            readonly property string icon: model.icon
            readonly property color color: root.Theme.palette.primaryColor1
            readonly property bool hasNotification: model.badgeCount > 0
            readonly property int notificationsCount: model.badgeCount

            readonly property bool isExperimental: model.isExperimental
        }
        expectedRoles: ["subsection", "text", "icon", "badgeCount", "isExperimental"]
        exposedRoles: ["key", "id", "name", "icon", "color", "hasNotification", "notificationsCount",
            "isExperimental"]
    }

    ObjectProxyModel {
        id: chatsModel
        sourceModel: SortFilterProxyModel {
            sourceModel: root.chatsBaseModel
            filters: [
                ValueFilter {
                    roleName: "isCategory"
                    value: false
                }
            ]
        }
        delegate: QtObject {
            readonly property string key: Constants.appSection.chat + ';' + model.itemId
            readonly property string id: model.itemId
            readonly property string name: model.name
            readonly property string icon: model.icon || model.emoji
            readonly property string lastMessageText: model.lastMessageText
            readonly property color color: model.color || Utils.colorForColorId(root.Theme.palette, model.colorId)
            readonly property bool hasNotification: model.hasUnreadMessages || model.notificationsCount
            readonly property int notificationsCount: model.notificationsCount

            readonly property int chatType: model.type // cf. Constants.chatType.*
            readonly property int onlineStatus: model.onlineStatus // cf. Constants.onlineStatus.*
        }

        expectedRoles: ["itemId", "type", "name", "emoji", "icon", "color", "colorId", "hasUnreadMessages", "notificationsCount", "onlineStatus", "lastMessageText"]
        exposedRoles: ["key", "id", "chatType", "name", "icon", "color", "hasNotification", "notificationsCount", "onlineStatus", "lastMessageText"]
    }

    ObjectProxyModel {
        id: chatsSearchModel
        sourceModel: SortFilterProxyModel {
            sourceModel: root.chatsSearchBaseModel
            filters: [
                ValueFilter {
                    roleName: "chatType"
                    value: Constants.chatType.communityChat
                }
            ]
        }
        delegate: QtObject {
            readonly property string key: model.sectionId + ';' + model.chatId
            readonly property string id: model.chatId
            readonly property string name: model.name
            readonly property string icon: model.icon || model.emoji
            readonly property string lastMessageText: model.lastMessageText
            readonly property color color: model.color || Utils.colorForColorId(root.Theme.palette, model.colorId)
        }

        expectedRoles: ["sectionId", "chatId", "chatType", "name", "sectionName", "emoji", "icon", "color", "colorId", "lastMessageText"]
        exposedRoles: ["key", "id", "name", "icon", "color", "lastMessageText"]
    }

    ObjectProxyModel {
        id: walletsModel

        sourceModel: root.walletsBaseModel
        delegate: QtObject {
            readonly property string key: Constants.appSection.wallet + ';' + model.mixedcaseAddress
            readonly property string id: model.mixedcaseAddress
            readonly property string name: model.name
            readonly property string icon: model.emoji
            readonly property color color: Utils.getColorForId(root.Theme.palette, model.colorId ?? Constants.walletAccountColors.primary)
            readonly property bool hasNotification: false
            readonly property int notificationsCount: 0

            readonly property string walletType: model.walletType
            readonly property string currencyBalance: LocaleUtils.currencyAmountToLocaleString(model.currencyBalance)
        }
        expectedRoles: ["mixedcaseAddress", "name", "emoji", "colorId", "walletType", "currencyBalance"]
        exposedRoles: ["key", "id", "name", "icon", "color", "hasNotification", "notificationsCount", "walletType", "currencyBalance"]
    }

    ObjectProxyModel {
        id: dappsModel

        sourceModel: root.dappsBaseModel
        delegate: QtObject {
            readonly property string key: Constants.appSection.dApp + ';' + model.url
            readonly property string id: model.url
            readonly property string name: model.name || StringUtils.extractDomainFromLink(model.url)
            readonly property string icon: model.iconUrl || "dapp"
            readonly property color color: root.Theme.palette.primaryColor1

            readonly property url connectorBadge: model.connectorBadge
        }
        expectedRoles: ["url", "name", "iconUrl", "connectorBadge"]
        exposedRoles: ["key", "id", "name", "icon", "color", "connectorBadge"]
    }

    ConcatModel {
        id: combinedModel
        sources: [
            SourceModel {
                model: root.showCommunities ? communitiesModel : null
                markerRoleValue: Constants.appSection.community
            },
            SourceModel {
                model: root.showWallets ? walletsModel : null
                markerRoleValue: Constants.appSection.wallet
            },
            SourceModel {
                model: root.showSettings ? settingsModel : null
                markerRoleValue: Constants.appSection.profile
            },
            SourceModel {
                model: root.showChats ? chatsModel : null
                markerRoleValue: Constants.appSection.chat
            },
            SourceModel {
                model: root.showChats ? chatsSearchModel : null
                markerRoleValue: -1 // search, no section
            },
            SourceModel {
                model: root.showDapps ? dappsModel : null
                markerRoleValue: Constants.appSection.dApp
            }
        ]

        markerRoleName: "sectionType"
        expectedRoles: ["key", "id", "enabled", "name", "icon", "color", "hasNotification", "notificationsCount", // common props
            "chatType", "onlineStatus", "lastMessageText", // chat
            "sectionName", // chat search
            "banner", "members", "activeMembers", "pending", "banned", // community
            "isExperimental", // settings
            "walletType", "currencyBalance", // wallet
            "connectorBadge" // dapp
        ]
    }

    Settings {
        id: homePageSettings
        category: "HomePage_%1".arg(root.profileId)
    }

    ObjectProxyModel { // provides a writable overlay for "timestamp" and "pinned" roles
        id: homePageProxyModel

        sourceModel: combinedModel
        delegate: QtObject {
            property real timestamp
            property bool pinned
        }

        exposedRoles: ["timestamp", "pinned"]
    }

    function setPinned(key, pinned) {
        const idx = ModelUtils.indexOf(homePageProxyModel, "key", key)
        if (idx > -1) {
            homePageProxyModel.proxyObject(idx).pinned = pinned
        }
    }

    function setTimestamp(key, timestamp) {
        const idx = ModelUtils.indexOf(homePageProxyModel, "key", key)
        if (idx > -1) {
            homePageProxyModel.proxyObject(idx).timestamp = timestamp
        }
    }

    function save() {
        const dataArray = ModelUtils.modelToArray(homePageProxyModel, ["key", "timestamp", "pinned"])
        const settingsData = JSON.stringify(dataArray)
        homePageSettings.setValue("HomePageEntries", settingsData)
        homePageSettings.sync()
    }

    function load() {
        const settingsData = homePageSettings.value("HomePageEntries")
        let dataArray = []

        try {
            dataArray = JSON.parse(settingsData)
        } catch (e) {
            console.warn("Error parsing HomePageEntries:", e.message)
            return
        }

        dataArray.forEach(function(item) {
            const idx = ModelUtils.indexOf(homePageProxyModel, "key", item.key)
            if (idx > -1) {
                homePageProxyModel.proxyObject(idx).pinned = item.pinned
                homePageProxyModel.proxyObject(idx).timestamp = item.timestamp
            }
        })
    }

    SortFilterProxyModel {
        id: filteredCombinedModel
        sourceModel: homePageProxyModel

        filters: [
            SearchFilter {
                roleName: "name"
                searchPhrase: root.searchPhrase
            },
            ValueFilter {
                roleName: "sectionType"
                value: -1 // search only
                inverted: true
                enabled: root.searchPhrase === "" && !root.showAllChats
            }
        ]
        sorters: [
            RoleSorter {
                roleName: "timestamp"
                sortOrder: Qt.DescendingOrder
            },
            RoleSorter {
                roleName: "name"
            }
        ]
    }
}
