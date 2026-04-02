import QtQuick

import StatusQ.Core.Theme
import StatusQ.Core.Utils

import AppLayouts.Chat.stores
import AppLayouts.Communities.stores
import AppLayouts.Profile.helpers
import utils

import SortFilterProxyModel

QtObject {
    id: root
    property bool localBackupEnabled: false

    required property ThemePalette palette

    readonly property QtObject _d: QtObject {
        id: d

        readonly property var mainModuleInst: mainModule
        readonly property var profileSectionModuleInst: profileSectionModule
    }

    property ProfileStore profileStore: ProfileStore {
        profileModule: d.profileSectionModuleInst.profileModule
        sectionsModel: d.mainModuleInst.sectionsModel
        ownAccounts: root.walletStore.ownAccounts
        collectibles: root.walletStore.collectibles
    }

    property KeycardStore keycardStore: KeycardStore {
        keycardModule: d.profileSectionModuleInst.keycardModule
    }

    property KeycardNewStore keycardNewStore: KeycardNewStore {
        keycardNewModule: d.profileSectionModuleInst.keycardNewModule
    }

    property EnsUsernamesStore ensUsernamesStore: EnsUsernamesStore {
        ensUsernamesModule: d.profileSectionModuleInst.ensUsernamesModule
    }

    property DevicesStore devicesStore: DevicesStore {
        devicesModule: d.profileSectionModuleInst.devicesModule
        syncModule: d.profileSectionModuleInst.syncModule
        localBackupEnabled: root.localBackupEnabled
    }

    property PrivacyStore privacyStore: PrivacyStore {
        privacyModule: d.profileSectionModuleInst.privacyModule
    }

    property NotificationsStore notificationsStore: NotificationsStore {
        notificationsModule: d.profileSectionModuleInst.notificationsModule
    }

    property AdvancedStore advancedStore: AdvancedStore {
        walletModule: d.profileSectionModuleInst.walletModule
        advancedModule: d.profileSectionModuleInst.advancedModule
    }

    property AboutStore aboutStore: AboutStore {}

    // TODO: Move to wallet related store
    property WalletStore walletStore: WalletStore {
        walletModule: d.profileSectionModuleInst.walletModule
        palette: root.palette
    }
}
