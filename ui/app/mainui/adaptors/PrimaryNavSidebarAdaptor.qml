import QtQml

import StatusQ.Core.Utils as SQUtils

import SortFilterProxyModel

import utils

SQUtils.QObject {
    id: root

    /**
      Expected model structure

        id                  [string] - unique id of the section
        sectionType         [int]    - type of this section (Constants.appSection.*)
        name                [string] - section's name, e.g. "Chat" or "Wallet" or a community name
        icon                [string] - section's icon (url like or blob)
        color               [color]  - the section's color
        banner              [string] - the section's banner image (url like or blob), mostly empty for non-communities
        hasNotification     [bool]   - whether the section has any notification (w/o denoting the number)
        notificationsCount  [int]    - number of notifications, if any
        enabled             [bool]   - whether the section should show in the UI
        active              [bool]   - whether the section is currently active
    **/
    required property var sectionsModel

    required property bool marketEnabled
    required property bool browserEnabled
    required property bool nodeEnabled

    property bool showEnabledSectionsOnly: true

    readonly property var regularItemsModel: SortFilterProxyModel {
        sourceModel: sectionsModelInternal
        filters: AnyOf {
            ValueFilter {
                roleName: "sectionType"
                value: Constants.appSection.homePage
            }
            ValueFilter {
                roleName: "sectionType"
                value: Constants.appSection.wallet
            }
            ValueFilter {
                roleName: "sectionType"
                value: Constants.appSection.swap
                enabled: !root.marketEnabled
            }
            ValueFilter {
                roleName: "sectionType"
                value: Constants.appSection.market
                enabled: root.marketEnabled
            }
            ValueFilter {
                roleName: "sectionType"
                value: Constants.appSection.chat
            }
            ValueFilter {
                roleName: "sectionType"
                value: Constants.appSection.browser
                enabled: root.browserEnabled
            }
            ValueFilter {
                roleName: "sectionType"
                value: Constants.appSection.node
                enabled: root.nodeEnabled
            }
        }
    }

    readonly property var communityItemsModel: SortFilterProxyModel {
        sourceModel: sectionsModelInternal
        filters: [
            ValueFilter {
                roleName: "sectionType"
                value: Constants.appSection.community
            }
        ]
    }

    readonly property var bottomItemsModel: SortFilterProxyModel {
        sourceModel: sectionsModelInternal
        filters: AnyOf {
            ValueFilter {
                roleName: "sectionType"
                value: Constants.appSection.communitiesPortal
            }
            ValueFilter {
                roleName: "sectionType"
                value: Constants.appSection.profile
            }
        }
        sorters: [
            RoleSorter {
                roleName: "sectionType"
                sortOrder: Qt.DescendingOrder
            }
        ]
    }

    // internal
    SortFilterProxyModel {
        id: sectionsModelInternal
        sourceModel: root.sectionsModel
        filters: [
            ValueFilter {
                roleName: "sectionType"
                value: Constants.appSection.loadingSection
                inverted: true
            },
            ValueFilter {
                roleName: "enabled"
                value: true
                enabled: root.showEnabledSectionsOnly
            }
        ]
        sorters: [
            RoleSorter { roleName: "sectionType" }
        ]
    }
}
