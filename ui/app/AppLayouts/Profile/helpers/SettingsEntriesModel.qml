import QtQuick

import utils

import QtModelsToolkit
import SortFilterProxyModel

/*!
    \qmltype SettingsEntriesModel
    \inherits SortFilterProxyModel
    \inqmlmodule AppLayouts.Profile.helpers

    Model providing entries to the settings section.

    Model structure:

    subsection          [int]    - identifier of the entry (Constants.settingsSubsection)
    text                [string] - readable name of the entry
    icon                [string] - icon name
    badgeCount          [int]    - number presented on the badge
    isExperimental      [bool]   - indicates if the beta tag should be presented
    experimentalTooltip [string] - tooltip text for the beta tag
*/
SortFilterProxyModel {
    id: root

    // Determines if wallet-related entries should be included
    property bool showWalletEntries

    // Determines if browser-related entries should be included
    property bool showBrowserEntries

    // Determines if back up seed phrase entry should be included
    property bool showBackUpSeed

    // Badge count for the back up seed phrase entry
    property int backUpSeedBadgeCount: 0

    // Determines if keycard-related entries should be included
    property bool isKeycardEnabled: true

    // Determines if local (on-device) backup entries are included
    property bool localBackupEnabled: true

    // Badge count for the syncing entry
    property int syncingBadgeCount: 0

    // Badge count for the messaging section
    property int messagingBadgeCount: 0

    // Whether to show subpages, like Contacts
    property bool showSubSubSections

    readonly property string appsGroupTitle: qsTr("Apps")
    readonly property string preferencesGroupTitle: qsTr("Preferences")
    readonly property string aboutAndHelpGroupTitle: qsTr("About & Help")

    readonly property var entries: [
        {
            subsection: Constants.settingsSubsection.backUpSeed,
            text: root.backUpSeedBadgeCount ? qsTr("Back up recovery phrase") : qsTr("Recovery phrase"),
            icon: "seed-phrase",
            isExperimental: false
        },
        {
            subsection: Constants.settingsSubsection.profile,
            text: qsTr("Profile"),
            icon: "profile",
            isExperimental: false
        },
        {
            subsection: Constants.settingsSubsection.password,
            text: qsTr("Password"),
            icon: "password",
            isExperimental: false
        },
        {
            subsection: Constants.settingsSubsection.keycard,
            text: qsTr("Keycard"),
            icon: "keycard",
            isExperimental: false
        },
        // TODO: enable when integrate keycard settings
        // {
        //     subsection: Constants.settingsSubsection.keycardNew,
        //     text: qsTr("Keycard New"),
        //     icon: "keycard",
        //     isExperimental: false
        // },
        {
            subsection: Constants.settingsSubsection.ensUsernames,
            text: qsTr("ENS usernames"),
            icon: "username",
            isExperimental: true,
            experimentalTooltip: qsTr("This section is going through a redesign.")
        },
        {
            subsection: Constants.settingsSubsection.syncingSettings,
            text: qsTr("Syncing"),
            icon: "rotate",
            isExperimental: true,
            experimentalTooltip: qsTr("Connection problems can happen.<br>If they do, please use the Enter a Recovery Phrase feature instead.")
        },
        {
            subsection: Constants.settingsSubsection.backupSettings,
            text: qsTr("On-device backup"),
            icon: "download",
            isExperimental: false
        },
        {
            subsection: Constants.settingsSubsection.messaging,
            text: qsTr("Messaging"),
            icon: "chat",
            group: root.appsGroupTitle,
            isExperimental: false
        },
        {
            subsection: Constants.settingsSubsection.contacts,
            text: qsTr("Contacts"),
            icon: "contact",
            isExperimental: false
        },
        {
            subsection: Constants.settingsSubsection.wallet,
            text: qsTr("Wallet"),
            icon: "wallet",
            group: root.appsGroupTitle,
            isExperimental: false
        },
        {
            subsection: Constants.settingsSubsection.browserSettings,
            text: qsTr("Browser"),
            icon: "browser",
            group: root.appsGroupTitle,
            isExperimental: true
        },
        {
            subsection: Constants.settingsSubsection.communitiesSettings,
            text: qsTr("Communities"),
            icon: "communities",
            group: root.appsGroupTitle,
            isExperimental: false
        },
        {
            subsection: Constants.settingsSubsection.privacyAndSecurity,
            text: qsTr("Privacy and security"),
            icon: "security",
            group: root.preferencesGroupTitle,
            isExperimental: false
        },
        {
            subsection: Constants.settingsSubsection.appearance,
            text: qsTr("Appearance"),
            icon: "appearance",
            group: root.preferencesGroupTitle,
            isExperimental: false
        },
        {
            subsection: Constants.settingsSubsection.notifications,
            text: qsTr("Notifications & Sounds"),
            icon: "notification",
            group: root.preferencesGroupTitle,
            isExperimental: false
        },
        {
            subsection: Constants.settingsSubsection.language,
            text: qsTr("Language & Currency"),
            icon: "language",
            group: root.preferencesGroupTitle,
            isExperimental: false
        },
        {
            subsection: Constants.settingsSubsection.advanced,
            text: qsTr("Advanced"),
            icon: "settings-advanced",
            group: root.preferencesGroupTitle,
            isExperimental: false
        },
        {
            subsection: Constants.settingsSubsection.about,
            text: qsTr("About"),
            icon: "info",
            group: root.aboutAndHelpGroupTitle,
            isExperimental: false
        },
        {
            subsection: Constants.settingsSubsection.signout,
            text: qsTr("Sign out & Quit"),
            icon: "logout",
            group: root.aboutAndHelpGroupTitle,
            isExperimental: false
        }
    ]

    // Update model after retranslation
    onEntriesChanged: {
        if (baseModel.count === 0)
            return

        entries.forEach((elem, index) => {
            baseModel.setProperty(index, "text", elem.text)

            if (elem.group)
                baseModel.setProperty(index, "group", elem.group)
        })
    }

    function getNameForSubsection(subsection) {
        const entry = root.entries.find(entry => entry.subsection === subsection)
        return entry ? entry.text : ""
    }

    sourceModel: ObjectProxyModel {
        sourceModel: ListModel {
            id: baseModel

            Component.onCompleted: append(root.entries)
        }

        delegate: QtObject {
            readonly property string objectName: "settingsNav_" + model.subsection
            readonly property bool visible: {
                switch (model.subsection) {
                    case Constants.settingsSubsection.ensUsernames:
                    case Constants.settingsSubsection.wallet:
                        return root.showWalletEntries
                    case Constants.settingsSubsection.browserSettings:
                        return root.showBrowserEntries
                    case Constants.settingsSubsection.backUpSeed:
                        return root.showBackUpSeed
                    case Constants.settingsSubsection.keycard:
                        return root.isKeycardEnabled
                    case Constants.settingsSubsection.keycardNew:
                        return root.isKeycardEnabled
                    case Constants.settingsSubsection.contacts:
                        return root.showSubSubSections
                    case Constants.settingsSubsection.backupSettings:
                        return root.localBackupEnabled

                    default: return true
                }
            }

            readonly property int badgeCount: {
                switch (model.subsection) {
                    case Constants.settingsSubsection.backUpSeed:
                        return root.backUpSeedBadgeCount
                    case Constants.settingsSubsection.syncingSettings:
                        return root.syncingBadgeCount
                    case Constants.settingsSubsection.messaging:
                        return root.messagingBadgeCount

                    default: return 0
                }
            }
        }

        expectedRoles: ["subsection"]
        exposedRoles: ["visible", "badgeCount", "objectName"]
    }

    filters: ValueFilter {
        roleName: "visible"
        value: true
    }
}
