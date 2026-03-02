import QtQuick

import StatusQ.Core.Utils as SQUtils

import utils

import AppLayouts.Wallet

import AppLayouts.stores
import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Profile.stores
import StatusQ.Core.Theme

import shared.stores as SharedStores

// The purpose of this class is to be the central point for generating toasts in the application.
// It will have as input all needed stores.
// In case the file grows considerably, consider creating different toasts managers per topic / context
// and just instantiate them in here.
QtObject {
    id: root

    // Here there are defined some specific actions needed by a toast.
    // They are normally specific navigations or open popup action.
    enum ActionType {
        None = 0,
        NavigateToCommunityAdmin = 1,
        OpenFinaliseOwnershipPopup = 2,
        OpenSendModalPopup = 3,
        ViewTransactionDetails = 4,
        OpenFirstCommunityTokenPopup = 5,
        OpenNewsMessagePopup = 6
    }

    // Stores:
    required property RootStore rootStore
    required property ContactsStore contactsStore
    required property ChatStores.RootStore rootChatStore
    required property SharedStores.CommunityTokensStore communityTokensStore
    required property ProfileStore profileStore
    required property DevicesStore devicesStore

    // Utils:
    readonly property string checkmarkCircleAssetName: "checkmark-circle"
    readonly property string crownOffAssetName: "crown-off"
    readonly property string warningAssetName: "warning"

    signal sendRequested

    // Community Transfer Ownership related toasts:
    readonly property Connections _communityTokensStoreConnections: Connections {
        target: root.communityTokensStore

        // Ownership Receiver:
        function onOwnerTokenReceived(communityId, communityName) {
            let communityColor = root.rootChatStore.getCommunityDetailsAsJson(communityId).color
            Global.displayToastWithActionMessage(qsTr("You received the Owner token for %1. To finalize ownership, make your device the control node.").arg(communityName),
                                                 qsTr("Finalise ownership"),
                                                 "crown",
                                                 communityColor,
                                                 false,
                                                 Constants.ephemeralNotificationType.normal,
                                                 ToastsManager.ActionType.OpenFinaliseOwnershipPopup,
                                                 communityId)
        }


        function onCommunityOwnershipDeclined(communityName) {
            Global.displayToastWithActionMessage(qsTr("You declined ownership of %1.").arg(communityName),
                                                 qsTr("Return owner token to sender"),
                                                 root.crownOffAssetName,
                                                 "",
                                                 false,
                                                 Constants.ephemeralNotificationType.danger,
                                                 ToastsManager.ActionType.OpenSendModalPopup,
                                                 "")
        }


        function onOwnershipLost(communityId, communityName) {
            Global.displayToastMessage(qsTr("Your device is no longer the control node for %1.
                                             Your ownership and admin rights for %1 have been transferred to the new owner.").arg(communityName),
                                       "",
                                       root.crownOffAssetName,
                                       false,
                                       Constants.ephemeralNotificationType.danger,
                                       "")
        }

        // Community token received in the user wallet:
        function onCommunityTokenReceived(name, symbol, image, communityId, communityName, balance, chainId, txHash, isFirst, tokenType, walletAddress, walletAccountName) {

            // Some error control:
            if(tokenType !== Constants.TokenType.ERC20 && tokenType !== Constants.TokenType.ERC721) {
                console.warn("Community token Received: Unexpected token type while creating a toast message: " + tokenType)
                return
            }

            // Double check if balance is string, then strip ending zeros (e.g. 1.0 -> 1)
            if (typeof balance === 'string' && balance.endsWith('0')) {
                balance = parseFloat(balance)
                if (isNaN(balance))
                    balance = "1"
                // Cast to Number to drop trailing zeros
                balance = Number(balance).toString()
            }

            var data = {
                communityId: communityId,
                communityName: communityName,
                chainId: chainId,
                txHash: txHash,
                tokenType: tokenType,
                tokenName: name,
                tokenSymbol: symbol,
                tokenImage: image,
                tokenAmount: balance,
                walletAddress: walletAddress
            }

            if(isFirst) {
                var tokenTypeText = ""
                if(tokenType === Constants.TokenType.ERC20) {
                    tokenTypeText = qsTr("You received your first community asset")
                } else if(tokenType === Constants.TokenType.ERC721) {
                    tokenTypeText = qsTr("You received your first community collectible")
                }

                // First community token received toast:
                Global.displayImageToastWithActionMessage(qsTr("%1: %2 %3").arg(tokenTypeText).arg(balance).arg(name),
                                                          qsTr("Learn more"),
                                                          image,
                                                          Constants.ephemeralNotificationType.normal,
                                                          ToastsManager.ActionType.OpenFirstCommunityTokenPopup,
                                                          JSON.stringify(data))
            } else {
                // Generic community token received toast:
                Global.displayImageToastWithActionMessage(qsTr("You were airdropped %1 %2 from %3 to %4").arg(balance).arg(name).arg(communityName).arg(walletAccountName),
                                                          qsTr("View transaction details"),
                                                          image,
                                                          Constants.ephemeralNotificationType.normal,
                                                          ToastsManager.ActionType.ViewTransactionDetails,
                                                          JSON.stringify(data))
            }
        }
    }

    // Connections to global. These will lead the backend integration:
    readonly property Connections _globalConnections: Connections {
        target: Global

        function onDisplayToastMessage(title: string, subTitle: string, icon: string, loading: bool, ephNotifType: int, url: string) {
            root.rootStore.displayEphemeralNotification(
                title,
                subTitle,
                "", // image
                icon,
                "", // iconColor
                loading,
                ephNotifType,
                0, // actionType
                "", // actionData
                url
            )
        }

        // TO UNIFY with the one above.
        // Further refactor will be done in a next step
        function onDisplayToastWithActionMessage(title: string, subTitle: string, icon: string, iconColor: string, loading: bool, ephNotifType: int, actionType: int, actionData: string) {
            root.rootStore.displayEphemeralNotification(
                title,
                subTitle,
                "", // image
                icon,
                iconColor,
                loading,
                ephNotifType,
                actionType,
                actionData,
                "" // url
            )
        }

        function onDisplayImageToastWithActionMessage(title: string, subTitle: string, image: string, ephNotifType: int, actionType: int, actionData: string) {
            root.rootStore.displayEphemeralNotification(
                title,
                subTitle,
                image,
                "", // icon
                "", // iconColor
                false, // loading
                ephNotifType,
                actionType,
                actionData,
                "" // url
            )
        }
    }

    readonly property Connections _mainConnections: Connections {
        target: root.rootStore

        function onShowEphemeralNewsNotification(newsTitle: string, notificationId: string) {
            Global.displayImageToastWithActionMessage(
                newsTitle,
                qsTr("Read more"),
                Assets.png("status-logo"),
                Constants.ephemeralNotificationType.normal,
                ToastsManager.ActionType.OpenNewsMessagePopup,
                notificationId
            )
        }
    }

    // Profile settings related toasts:
    readonly property Connections _profileStoreConnections: Connections {
        target: root.profileStore

        function onProfileSettingsSaveSucceeded() {
            Global.displayToastMessage(qsTr("Profile changes saved"),
                                       "",
                                       root.checkmarkCircleAssetName,
                                       false,
                                       Constants.ephemeralNotificationType.success,
                                       "")
        }

        function onProfileSettingsSaveFailed() {
            Global.displayToastMessage(qsTr("Profile changes could not be saved"),
                                       "",
                                       root.warningAssetName,
                                       false,
                                        Constants.ephemeralNotificationType.danger,
                                       "")
        }
    }

    readonly property Connections _contactStoreConnections: Connections {
        target: root.contactsStore

        function onTrustStatusRemoved(pubKey: string) {
            const displayName = SQUtils.ModelUtils.getByKey(root.contactsStore.contactsModel, "pubKey", pubKey, "preferredDisplayName")
            Global.displaySuccessToastMessage(qsTr("Trust mark removed for %1").arg(displayName))
        }
    }

    readonly property Connections _devicesStoreConnections: Connections {
        target: root.devicesStore

        function onLocalBackupExportCompleted(success: bool) {
            if (success) {
                Global.displaySuccessToastMessage(qsTr("Your data backed up successfully"))
            } else {
                Global.displayToastMessage(qsTr("Backup failed, please try again"),
                                       "",
                                       root.warningAssetName,
                                       false,
                                        Constants.ephemeralNotificationType.danger,
                                       "")
            }
        }
        function onLocalBackupImportCompleted(success: bool) {
            if (success) {
                Global.displaySuccessToastMessage(qsTr("Your data backup restored successfully"))
            } else {
                Global.displayToastMessage(qsTr("Import failed. Make sure the backup file matches your profile name."),
                                       "",
                                       root.warningAssetName,
                                       false,
                                        Constants.ephemeralNotificationType.danger,
                                       "")
            }
        }
    }

    // It will cover all specific actions (different than open external links) that can be done after clicking toast link text
    function doAction(actionType, actionData) {
        switch(actionType) {
        case ToastsManager.ActionType.NavigateToCommunityAdmin:
            root.rootChatStore.setActiveCommunity(actionData)
            return
        case ToastsManager.ActionType.OpenNewsMessagePopup:
            Global.openNewsMessagePopupRequested(actionData)
            return
        case ToastsManager.ActionType.OpenFinaliseOwnershipPopup:
            Global.openFinaliseOwnershipPopup(actionData)
            return
        case ToastsManager.ActionType.OpenSendModalPopup:
            root.sendRequested()
            return
        case ToastsManager.ActionType.ViewTransactionDetails:
            if(actionData) {
                var parsedData = JSON.parse(actionData)
                const txHash = parsedData.txHash
                const walletAddress = parsedData.walletAddress
                Global.changeAppSectionBySectionType(Constants.appSection.wallet,
                                                     WalletLayout.LeftPanelSelection.Address,
                                                     WalletLayout.RightPanelSelection.Activity,
                                                     {address: walletAddress,
                                                     txHash: txHash})
                return
            }
            console.warn("Unexpected transaction hash while trying to navigate to the details page")
            return
        case ToastsManager.ActionType.OpenFirstCommunityTokenPopup:
            if(actionData) {
                var data = JSON.parse(actionData)
                var communityId = data.communityId
                var communityName = data.communityName
                var tokenType = data.tokenType
                var tokenName = data.tokenName
                var tokenSymbol = data.tokenSymbol
                var tokenImage = data.tokenImage
                var tokenAmount = data.tokenAmount
                Global.openFirstTokenReceivedPopup(communityId,
                                                   communityName,
                                                   rootChatStore.getCommunityDetailsAsJson(communityId).image,
                                                   tokenSymbol,
                                                   tokenName,
                                                   tokenAmount,
                                                   tokenType,
                                                   tokenImage);
            }
            return
        default:
            console.warn("ToastsManager: Action type is not defined")
            return
        }
    }
}
