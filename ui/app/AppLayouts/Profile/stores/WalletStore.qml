import QtQuick

import utils

import StatusQ
import StatusQ.Models
import StatusQ.Core.Theme

import QtModelsToolkit
import SortFilterProxyModel

QtObject {
    id: root

    property var walletModule
    property var accountsModule: root.walletModule.accountsModule
    property var collectibles: _jointCollectiblesBySymbolModel

    property var accountSensitiveSettings: Global.appIsReady? localAccountSensitiveSettings : null
    readonly property var dappList: Global.appIsReady? dappPermissionsModule.dapps : null

    readonly property bool isWalletEnabled: Global.appIsReady ?
                                                mainModule.sectionsModel.getItemEnabledBySectionType(Constants.appSection.wallet) : true

    property var selectedAccount

    required property ThemePalette palette

    // TODO(alaibe): there should be no access to wallet section, create collectible in profile
    property var overview: walletSectionOverview
    property var accounts: Global.appIsReady? accountsModule.accounts : null
    property var originModel: accountsModule.keyPairModel
    property var ownAccounts: SortFilterProxyModel {
        sourceModel: root.accounts
        proxyRoles: [
            FastExpressionRole {
                name: "color"

                function getColor(palette, colorId) {
                    return Utils.getColorForId(palette, colorId)
                }

                // Direct call for singleton function is not handled properly by
                // SortFilterProxyModel that's why helper function is used instead.
                expression: { return getColor(root.palette, model.colorId) }
                expectedRoles: ["colorId"]
            }
        ]
        filters: ValueFilter {
            roleName: "walletType"
            value: Constants.watchWalletType
            inverted: true
        }
    }

    /* PRIVATE: This model renames the roles
        1. "id" to "communityId"
        2. "name" to "communityName"
        3. "image" to "communityImage"
        4. "description" to "communityDescription"
        in communitiesModule.model so that it can be easily
        joined with the Collectibles model */
    readonly property var _renamedCommunitiesModel: RolesRenamingModel {
        sourceModel: communitiesModule.model
        mapping: [
            RoleRename {
                from: "id"
                to: "communityId"
            },
            RoleRename {
                from: "name"
                to: "communityName"
            },
            RoleRename {
                from: "image"
                to: "communityImage"
            },
            RoleRename {
                from: "description"
                to: "communityDescription"
            }
        ]
    }

    /* PRIVATE: This model joins the "Tokens By Symbol Model" and "Communities Model" by communityId */
    property LeftJoinModel _jointCollectiblesBySymbolModel: LeftJoinModel {
        leftModel: root.walletModule.collectiblesModel
        rightModel: _renamedCommunitiesModel
        joinRole: "communityId"
    }

    property string userProfilePublicKey: userProfile.pubKey

    signal loggedInUserAuthenticated(string requestedBy, string password, string pin, string keyUid, string keycardUid)

    property QtObject d: QtObject {

        readonly property var mainModuleInst: mainModule
    }

    readonly property Connections authenticationConnections: Connections {
        target: Global

        function onAuthenticationResult(reason: string, password: string, pin: string, keyUid: string) {
            root.loggedInUserAuthenticated(reason, password, pin, keyUid, "")
        }
    }

    function authenticateLoggedInUser(requestedBy) {
        Global.openAuthenticationPopup(requestedBy, userProfile.keyUid, false)
    }

    function deleteAccount(address, password) {
        return accountsModule.deleteAccount(address, password)
    }

    function deleteKeypair(keyUid, password) {
        return accountsModule.deleteKeypair(keyUid, password)
    }

    function updateAccount(address, accountName, colorId, emoji) {
        return accountsModule.updateAccount(address, accountName, colorId, emoji)
    }

    function moveAccount(from, to) {
        root.accountsModule.moveAccount(from, to)
    }

    function moveAccountFinally(from, to) {
        root.accountsModule.moveAccountFinally(from, to)
    }

    function setSelectedAccount(address) {
        root.accountsModule.setSelectedAccount(address)
    }

    function runAddAccountPopup() {
        // TODO:
        // - `runAddAccountPopup` should be part of `root.walletModule`
        // - `AddAccountPopup {}` should be moved from `MainView` to `WalletView`
        // - `Edit account` popup opened from the wallet settings should be the same as one opened from the wallet section
        // - `walletSection` should not be used in the context of wallet settings
        walletSection.runAddAccountPopup(false)
    }

    function runKeypairImportPopup(keyUid, mode) {
        root.walletModule.runKeypairImportPopup(keyUid, mode)
    }


    function updateWatchAccountHiddenFromTotalBalance(address, hideFromTotalBalance) {
        accountsModule.updateWatchAccountHiddenFromTotalBalance(address, hideFromTotalBalance)
    }

    function getRpcStats() {
        return root.walletModule.getRpcStats()
    }

    function resetRpcStats() {
        root.walletModule.resetRpcStats()
    }
}
