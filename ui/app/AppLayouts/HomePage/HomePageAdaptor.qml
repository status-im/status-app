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

    readonly property var homePageEntriesModel: entriesModel

    // SettingsEntriesModel fills its ListModel in its own Component.onCompleted, which runs after
    // this one; load() drops saved entries whose rows are absent, so defer it until they exist
    Component.onCompleted: Qt.callLater(load)

    Component.onDestruction: save()

    QtObject {
        id: d

        readonly property var computedRolesNames: ["icon", "color", "hasNotification", "pending", "currencyBalance"]
        readonly property var computedRolesInputs: [
            "sectionType", "icon", "sourceIcon", "emoji", "iconUrl", "color", "sourceColor", "colorId",
            "hasNotification", "hasUnreadMessages", "notificationsCount", "spectated", "joined",
            "sourceCurrencyBalance"
        ]
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
    readonly property var pinnedModel: ObjectProxyModel {
        sourceModel: SortFilterProxyModel {
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
        delegate: computedRoles
        expectedRoles: d.computedRolesInputs
        exposedRoles: d.computedRolesNames
    }

    function clear() {
        homePageProxyModel.clear()
    }

    // The per-source models below only rename source roles and add cheap C++ proxy roles: sorting,
    // filtering, search and the writable overlay work on them without per-row objects. Roles computed
    // in JS are added at the very end (ObjectProxyModel), only for rows a view requests.
    SortFilterProxyModel {
        id: communitiesModel

        sourceModel: RolesRenamingModel {
            sourceModel: root.sectionsBaseModel
            mapping: [
                RoleRename { from: "icon"; to: "sectionIcon" },
                RoleRename { from: "image"; to: "icon" },
                RoleRename { from: "bannerImageData"; to: "banner" },
                RoleRename { from: "joinedMembersCount"; to: "members" },
                RoleRename { from: "activeMembersCount"; to: "activeMembers" },
                RoleRename { from: "amIBanned"; to: "banned" }
            ]
        }
        filters: ValueFilter {
            roleName: "sectionType"
            value: Constants.appSection.community
        }
        proxyRoles: [
            ConstantRole { name: "keyPrefix"; value: Constants.appSection.community },
            JoinRole { name: "key"; roleNames: ["keyPrefix", "id"]; separator: ";" }
        ]
    }

    SortFilterProxyModel {
        id: settingsModel

        sourceModel: RolesRenamingModel {
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
            mapping: [
                RoleRename { from: "text"; to: "name" },
                RoleRename { from: "badgeCount"; to: "notificationsCount" }
            ]
        }
        proxyRoles: [
            ConstantRole { name: "keyPrefix"; value: Constants.appSection.profile },
            JoinRole { name: "key"; roleNames: ["keyPrefix", "subsection"]; separator: ";" },
            JoinRole { name: "id"; roleNames: ["subsection"] },
            ConstantRole { name: "color"; value: root.Theme.palette.primaryColor1 }
        ]
    }

    SortFilterProxyModel {
        id: chatsModel

        sourceModel: RolesRenamingModel {
            sourceModel: root.chatsBaseModel
            mapping: [
                RoleRename { from: "type"; to: "chatType" }, // cf. Constants.chatType.*
                RoleRename { from: "icon"; to: "sourceIcon" },
                RoleRename { from: "color"; to: "sourceColor" }
            ]
        }
        filters: ValueFilter {
            roleName: "isCategory"
            value: false
        }
        proxyRoles: [
            ConstantRole { name: "keyPrefix"; value: Constants.appSection.chat },
            JoinRole { name: "key"; roleNames: ["keyPrefix", "itemId"]; separator: ";" },
            JoinRole { name: "id"; roleNames: ["itemId"] }
        ]
    }

    SortFilterProxyModel {
        id: chatsSearchModel

        sourceModel: RolesRenamingModel {
            sourceModel: root.chatsSearchBaseModel ?? null
            mapping: [
                RoleRename { from: "icon"; to: "sourceIcon" },
                RoleRename { from: "color"; to: "sourceColor" }
            ]
        }
        filters: ValueFilter {
            roleName: "chatType"
            value: Constants.chatType.communityChat
        }
        proxyRoles: [
            JoinRole { name: "key"; roleNames: ["sectionId", "chatId"]; separator: ";" },
            JoinRole { name: "id"; roleNames: ["chatId"] }
        ]
    }

    SortFilterProxyModel {
        id: walletsModel

        sourceModel: RolesRenamingModel {
            sourceModel: root.walletsBaseModel
            mapping: RoleRename { from: "currencyBalance"; to: "sourceCurrencyBalance" }
        }
        proxyRoles: [
            ConstantRole { name: "keyPrefix"; value: Constants.appSection.wallet },
            JoinRole { name: "key"; roleNames: ["keyPrefix", "mixedcaseAddress"]; separator: ";" },
            JoinRole { name: "id"; roleNames: ["mixedcaseAddress"] },
            JoinRole { name: "icon"; roleNames: ["emoji"] },
            ConstantRole { name: "hasNotification"; value: false },
            ConstantRole { name: "notificationsCount"; value: 0 }
        ]
    }

    // dApps: the name used for sorting/searching is computed, so this (small) source keeps an
    // ObjectProxyModel of its own
    ObjectProxyModel {
        id: dappsModel

        sourceModel: SortFilterProxyModel {
            sourceModel: root.dappsBaseModel
            proxyRoles: [
                ConstantRole { name: "keyPrefix"; value: Constants.appSection.dApp },
                JoinRole { name: "key"; roleNames: ["keyPrefix", "url"]; separator: ";" },
                JoinRole { name: "id"; roleNames: ["url"] },
                ConstantRole { name: "color"; value: root.Theme.palette.primaryColor1 }
            ]
        }
        delegate: QtObject {
            readonly property string name: model.name || StringUtils.extractDomainFromLink(model.url)
        }
        expectedRoles: ["name", "url"]
        exposedRoles: ["name"]
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
            "connectorBadge", // dapp
            // inputs of the computed roles (computedRoles)
            "sourceIcon", "emoji", "iconUrl", "sourceColor", "colorId", "hasUnreadMessages",
            "spectated", "joined", "sourceCurrencyBalance"
        ]
    }

    Settings {
        id: homePageSettings
        category: "HomePage_%1".arg(root.profileId)
    }

    RolesOverlayModel { // provides a writable overlay for "timestamp" and "pinned" roles
        id: homePageProxyModel

        sourceModel: combinedModel
        keyRole: "key"
        defaults: ({ timestamp: 0, pinned: false })
    }

    function setPinned(key, pinned) {
        homePageProxyModel.set(key, "pinned", pinned)
    }

    function setTimestamp(key, timestamp) {
        homePageProxyModel.set(key, "timestamp", timestamp)
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

        homePageProxyModel.setEntries(dataArray)
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

    ObjectProxyModel {
        id: entriesModel

        sourceModel: filteredCombinedModel
        delegate: computedRoles
        expectedRoles: d.computedRolesInputs
        exposedRoles: d.computedRolesNames
    }

    // Roles computed in JS, per entry type; created only for rows requested by a view
    Component {
        id: computedRoles

        QtObject {
            readonly property int sectionType: model.sectionType
            readonly property bool isChat: sectionType === Constants.appSection.chat || sectionType === -1

            readonly property var icon: {
                if (isChat)
                    return model.sourceIcon || model.emoji || ""
                if (sectionType === Constants.appSection.dApp)
                    return model.iconUrl || "dapp"
                return model.icon
            }
            readonly property var color: {
                if (isChat)
                    return model.sourceColor || Utils.colorForColorId(root.Theme.palette, model.colorId)
                if (sectionType === Constants.appSection.wallet)
                    return Utils.getColorForId(root.Theme.palette, model.colorId ?? Constants.walletAccountColors.primary)
                return model.color
            }
            readonly property var hasNotification: {
                if (sectionType === Constants.appSection.chat)
                    return !!(model.hasUnreadMessages || model.notificationsCount)
                if (sectionType === Constants.appSection.profile)
                    return model.notificationsCount > 0
                return model.hasNotification
            }
            readonly property bool pending: sectionType === Constants.appSection.community
                                            && !!(model.spectated && !model.joined)
            readonly property string currencyBalance: sectionType === Constants.appSection.wallet
                                                      ? LocaleUtils.currencyAmountToLocaleString(model.sourceCurrencyBalance)
                                                      : ""
        }
    }
}
