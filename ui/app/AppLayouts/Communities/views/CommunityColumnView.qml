import QtCore
import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups
import StatusQ.Popups.Dialog

import utils
import shared
import shared.popups
import shared.status
import shared.controls.chat.menuItems
import shared.panels
import shared.stores
import shared.views.chat

import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Communities.popups
import AppLayouts.Communities.panels
import AppLayouts.Communities.stores as CommunitiesStores
import AppLayouts.Wallet.stores as WalletStores

// FIXME: Rework me to use ColumnLayout instead of anchors!!
Item {
    id: root
    objectName: "communityColumnView"
    width: Constants.chatSectionLeftColumnWidth
    height: parent.height

    // Important:
    // We're here in case of CommunitySection
    // This module is set from `ChatLayout` (each `ChatLayout` has its own communitySectionModule)
    property var communitySectionModule
    property var emojiPopup

    property ChatStores.RootStore store
    property CommunitiesStores.CommunitiesStore communitiesStore
    required property WalletStores.WalletAssetsStore walletAssetsStore
    required property CurrenciesStore currencyStore
    property var communityData
    property int joinedMembersCount
    property alias createChannelPopup: createChannelPopup

    property int requestToJoinState: Constants.RequestToJoinState.None

    // Community access related data:
    property var spectatedPermissionsModel

    // Settings related:
    property bool ensCommunityPermissionsEnabled

    // Community transfer ownership related props:
    required property bool isPendingOwnershipRequest
    signal finaliseOwnershipClicked

    readonly property bool isSectionAdmin:
        communityData.memberRole === Constants.memberRole.owner ||
        communityData.memberRole === Constants.memberRole.admin ||
        communityData.memberRole === Constants.memberRole.tokenMaster

    signal infoButtonClicked
    signal manageButtonClicked
    signal chatItemClicked(string id)

    // Permissions Related requests:
    signal createPermissionRequested(var holdings, int permissionType, bool isPrivate, var channels)
    signal removePermissionRequested(string key)
    signal editPermissionRequested(string key, var holdings, int permissionType, var channels, bool isPrivate)
    signal prepareTokenModelForCommunityChatRequested(string communityId, string chatId)

    QtObject {
        id: d

        readonly property bool showJoinButton: !communityData.joined || root.communityData.amIBanned
        readonly property bool showFinaliseOwnershipButton: root.isPendingOwnershipRequest
        readonly property bool discordImportInProgress: (root.communitiesStore.discordImportProgress > 0 && root.communitiesStore.discordImportProgress < 100)
                                                        || root.communitiesStore.discordImportInProgress

        readonly property int requestToJoinState: root.communitySectionModule.requestToJoinState
        readonly property bool invitationPending: d.requestToJoinState !== Constants.RequestToJoinState.None
    }

    ColumnHeaderPanel {
        id: communityHeader

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        name: communityData.name
        membersCount: root.joinedMembersCount
        image: communityData.image
        color: communityData.color
        amISectionAdmin: root.isSectionAdmin
        openCreateChat: root.store.openCreateChat
        onInfoButtonClicked: root.infoButtonClicked()
        onAdHocChatButtonClicked: root.store.openCloseCreateChatView()
    }

    Loader {
        id: columnHeaderButton

        anchors.top: communityHeader.bottom
        anchors.topMargin: Theme.halfPadding
        anchors.bottomMargin: Theme.halfPadding
        anchors.horizontalCenter: parent.horizontalCenter
        sourceComponent: d.showFinaliseOwnershipButton ? finaliseCommunityOwnershipBtn :
                                                         d.showJoinButton ? joinCommunityButton : undefined
        active: d.showFinaliseOwnershipButton || d.showJoinButton
    }

    ChatsLoadingPanel {
        chatSectionModule: root.communitySectionModule
        width: parent.width
        anchors.top: columnHeaderButton.active ? columnHeaderButton.bottom : communityHeader.bottom
        anchors.topMargin: active ? Theme.halfPadding : 0
    }

    StatusMenu {
        id: adminPopupMenu
        enabled: root.isSectionAdmin
        hideDisabledItems: !showInviteButton

        property bool showInviteButton: false

        onClosed: adminPopupMenu.showInviteButton = false

        StatusAction {
            objectName: "createCommunityChannelBtn"
            text: qsTr("Create channel")
            icon.name: "channel"
            onTriggered: Global.openPopup(createChannelPopup)
        }

        // hidden as part of https://github.com/status-im/status-app/issues/17726
        // StatusAction {
        //     objectName: "importCommunityChannelBtn"
        //     text: qsTr("Create channel via Discord import")
        //     icon.name: "download"
        //     enabled: !d.discordImportInProgress
        //     onTriggered: {
        //         Global.openPopup(createChannelPopup, {isDiscordImport: true, communityId: communityData.id})
        //     }
        // }

        StatusAction {
            objectName: "createCommunityCategoryBtn"
            text: qsTr("Create category")
            icon.name: "channel-category"
            onTriggered: Global.openPopup(createCategoryPopup)
        }

        StatusMenuSeparator {
            visible: invitePeopleBtn.enabled
        }

        StatusAction {
            id: invitePeopleBtn
            text: qsTr("Invite people")
            icon.name: "share-ios"
            enabled: communityData.canManageUsers && adminPopupMenu.showInviteButton
            objectName: "invitePeople"
            onTriggered: {
                Global.openInviteFriendsToCommunityPopup(root.communityData,
                                                         root.communitySectionModule,
                                                         null)
            }
        }
    }

    StatusScrollView {
        id: scrollView

        anchors.top: columnHeaderButton.active ? columnHeaderButton.bottom : communityHeader.bottom
        anchors.topMargin: Theme.halfPadding
        anchors.bottom: createChatOrCommunity.top
        anchors.horizontalCenter: parent.horizontalCenter

        width: parent.width

        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        contentWidth: availableWidth
        contentHeight: communityChatListAndCategories.height
                       + bannerColumn.height
                       + bannerColumn.anchors.topMargin

        StatusChatListAndCategories {
            id: communityChatListAndCategories
            width: scrollView.availableWidth
            draggableItems: root.isSectionAdmin
            draggableCategories: root.isSectionAdmin

            model: root.communitySectionModule.model
            highlightItem: !root.store.openCreateChat

            onChatItemSelected: {
                Global.closeCreateChatView()
                root.communitySectionModule.setActiveItem(id)
            }
            onChatItemClicked: (id) => {
                root.chatItemClicked(id)
            }

            showCategoryActionButtons: root.isSectionAdmin
            showPopupMenu: root.isSectionAdmin && communityData.canManageUsers

            onChatItemUnmuted: root.communitySectionModule.unmuteChat(id)
            onChatItemReordered: function(categoryId, chatId, to) {
                root.store.reorderCommunityChat(categoryId, chatId, to);
            }
            onChatListCategoryReordered: root.store.reorderCommunityCategories(categoryId, to)

            onCategoryAddButtonClicked: Global.openPopup(createChannelPopup, {
                                                             categoryId: id
                                                         })

            onToggleCollapsedCommunityCategory: root.store.toggleCollapsedCommunityCategory(categoryId, collapsed)

            popupMenu: StatusMenu {
                hideDisabledItems: false
                StatusAction {
                    text: qsTr("Create channel")
                    icon.name: "channel"
                    enabled: root.isSectionAdmin
                    onTriggered: Global.openPopup(createChannelPopup)
                }

                // hidden as part of https://github.com/status-im/status-app/issues/17726
                // StatusAction {
                //     objectName: "importCommunityChannelBtn"
                //     text: qsTr("Create channel via Discord import")
                //     icon.name: "download"
                //     enabled: !d.discordImportInProgress
                //     onTriggered: Global.openPopup(createChannelPopup, {isDiscordImport: true, communityId: root.communityData.id})
                // }

                StatusAction {
                    text: qsTr("Create category")
                    icon.name: "channel-category"
                    enabled: root.isSectionAdmin
                    onTriggered: Global.openPopup(createCategoryPopup)
                }

                StatusMenuSeparator {}

                StatusAction {
                    text: qsTr("Invite people")
                    icon.name: "share-ios"
                    enabled: communityData.canManageUsers
                    objectName: "invitePeople"
                    onTriggered: {
                        Global.openInviteFriendsToCommunityPopup(root.communityData,
                                                                 root.communitySectionModule,
                                                                 null)
                    }
                }
            }

            categoryPopupMenu: StatusMenu {
                id: contextMenuCategory
                property var categoryItem

                MuteChatMenuItem {
                    enabled: !!categoryItem && !categoryItem.muted
                    title: qsTr("Mute category")
                    onMuteTriggered: {
                        root.communitySectionModule.muteCategory(categoryItem.itemId, interval)
                        contextMenuCategory.close()
                    }
                }

                StatusAction {
                    enabled: !!categoryItem && categoryItem.muted
                    text: qsTr("Unmute category")
                    icon.name: "notification"
                    onTriggered: {
                        root.communitySectionModule.unmuteCategory(categoryItem.itemId)
                    }
                }

                StatusAction {
                    objectName: "editCategoryMenuItem"
                    enabled: root.isSectionAdmin
                    text: qsTr("Edit Category")
                    icon.name: "edit"
                    onTriggered: {
                        Global.openPopup(createCategoryPopup, {
                                             isEdit: true,
                                             channels: [],
                                             categoryId: categoryItem.itemId,
                                             categoryName: categoryItem.name
                                         })
                    }
                }

                StatusMenuSeparator {
                    visible: root.isSectionAdmin
                }

                StatusAction {
                    objectName: "deleteCategoryMenuItem"
                    enabled: root.isSectionAdmin
                    text: qsTr("Delete Category")
                    icon.name: "delete"
                    type: StatusAction.Type.Danger
                    onTriggered: {
                        Global.openPopup(deleteCategoryConfirmationDialogComponent, {
                                             "headerSettings.title": qsTr("Delete '%1' category").arg(categoryItem.name),
                                             confirmationText: qsTr("Are you sure you want to delete '%1' category? Channels inside the category won't be deleted.")
                                             .arg(categoryItem.name),
                                             categoryId: categoryItem.itemId
                                         })
                    }
                }
            }

            chatListPopupMenu: ChatContextMenuView {
                id: chatContextMenuView
                showDebugOptions: root.store.isDebugEnabled

                // TODO pass the chatModel in its entirety instead of fetching the JSOn using just the id
                openHandler: function (id) {
                    try {
                        let jsonObj = root.communitySectionModule.getItemAsJson(id)
                        let obj = JSON.parse(jsonObj)
                        if (obj.error) {
                            console.error("error parsing chat item json object, id: ", id, " error: ", obj.error)
                            close()
                            return
                        }

                        isCommunityChat = root.communitySectionModule.isCommunity()
                        amIChatAdmin = root.isSectionAdmin
                        chatId = obj.itemId
                        chatName = obj.name
                        chatDescription = obj.description
                        chatIcon = obj.icon
                        chatEmoji = obj.emoji
                        chatColor = obj.color
                        chatType = obj.type
                        chatMuted = obj.muted
                        channelPosition = obj.position
                        chatCategoryId = obj.categoryId
                        viewersCanPostReactions = obj.viewersCanPostReactions
                        hideIfPermissionsNotMet = obj.hideIfPermissionsNotMet
                    } catch (e) {
                        console.error("error parsing chat item json object, id: ", id, " error: ", e)
                        close()
                        return
                    }
                }

                onMuteChat: {
                    root.communitySectionModule.muteChat(chatId, interval)
                }

                onUnmuteChat: {
                    root.communitySectionModule.unmuteChat(chatId)
                }

                onMarkAllMessagesRead: {
                    root.communitySectionModule.markAllMessagesRead(chatId)
                }

                onClearChatHistory: {
                    root.communitySectionModule.clearChatHistory(chatId)
                }

                onLeaveChat: {
                    root.communitySectionModule.leaveChat(chatId)
                }

                onDeleteCommunityChat:  root.store.removeCommunityChat(chatId)

                onDisplayProfilePopup: {
                    Global.openProfilePopup(publicKey)
                }
                onDisplayEditChannelPopup: {
                    Global.openPopup(createChannelPopup, {
                        isEdit: true,
                        channelName: chatName,
                        channelDescription: chatDescription,
                        channelEmoji: chatEmoji,
                        channelColor: chatColor,
                        categoryId: chatCategoryId,
                        chatId: chatContextMenuView.chatId,
                        channelPosition: channelPosition,
                        viewOnlyCanAddReaction: viewersCanPostReactions,
                        deleteChatConfirmationDialog: deleteChatConfirmationDialog,
                        hideIfPermissionsNotMet: hideIfPermissionsNotMet
                    });
                }
            }
        }

        Column {
            id: bannerColumn
            width: scrollView.availableWidth
            anchors.top: communityChatListAndCategories.bottom
            anchors.topMargin: Theme.padding
            spacing: Theme.bigPadding

            Settings {
                id: bannerSettings
                category: "BannerSettings_%1".arg(communityData.id)
                property bool hiddenCommunityWelcomeBanners
                property bool hiddenCommunityChannelAndCategoriesBanners
            }

            Loader {
                active: root.isSectionAdmin && !bannerSettings.hiddenCommunityWelcomeBanners
                width: parent.width
                visible: active
                sourceComponent: Component {
                    WelcomeBannerPanel {
                        activeCommunity: communityData
                        communitySectionModule: root.communitySectionModule
                        onManageCommunityClicked: root.manageButtonClicked()
                        onHideBannerRequested: bannerSettings.hiddenCommunityWelcomeBanners = true
                    }
                }
            } // Loader

            Loader {
                active: root.isSectionAdmin && !bannerSettings.hiddenCommunityChannelAndCategoriesBanners
                width: parent.width
                visible: active
                sourceComponent: Component {
                    ChannelsAndCategoriesBannerPanel {
                        id: channelsAndCategoriesBanner
                        communityId: communityData.id
                        onAddMembersClicked: {
                            Global.openPopup(createChannelPopup);
                        }
                        onAddCategoriesClicked: {
                            Global.openPopup(createCategoryPopup);
                        }
                        onHideBannerRequested: bannerSettings.hiddenCommunityChannelAndCategoriesBanners = true
                    }
                }
            } // Loader
        } // Column

        background: Item {
            TapHandler {
                enabled: root.isSectionAdmin
                acceptedButtons: Qt.RightButton
                onTapped: {
                    adminPopupMenu.showInviteButton = true
                    adminPopupMenu.x = eventPoint.position.x + 4
                    adminPopupMenu.y = eventPoint.position.y + 4
                    adminPopupMenu.popup()
                }
            }
        }
    } // ScrollView

    Loader {
        id: createChatOrCommunity
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: active ? Theme.padding : 0
        active: root.isSectionAdmin
        sourceComponent: Component {
            StatusLinkText {
                id: createChannelOrCategoryBtn
                objectName: "createChannelOrCategoryBtn"
                height: visible ? implicitHeight : 0
                text: qsTr("Create channel or category")
                font.underline: true

                StatusMouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        adminPopupMenu.showInviteButton = false
                        adminPopupMenu.popup()
                        adminPopupMenu.y = Qt.binding(() => root.height - adminPopupMenu.height
                                                      - createChannelOrCategoryBtn.height - 20)
                    }
                }
            }
        }
    }

    Component {
        id: joinCommunityButton

        StatusButton {
            anchors.top: communityHeader.bottom
            anchors.topMargin: Theme.halfPadding
            anchors.bottomMargin: Theme.halfPadding
            anchors.horizontalCenter: parent.horizontalCenter
            enabled: !root.communityData.amIBanned
            loading: d.requestToJoinState === Constants.RequestToJoinState.InProgress

            text: {
                if (root.communityData.amIBanned) return qsTr("You were banned from community")
                if (d.requestToJoinState === Constants.RequestToJoinState.Requested) return qsTr("Membership request pending...")

                return root.communityData.access === Constants.communityChatOnRequestAccess ?
                            qsTr("Request to join") : qsTr("Join Community")
            }

            onClicked: {
                Global.communityIntroPopupRequested(communityData.id, communityData.name, communityData.introMessage,
                                                    communityData.image, d.invitationPending)
            }

            Connections {
                enabled: d.showJoinButton
                target: root.store.communitiesModuleInst

                function onCommunityAccessFailed(communityId: string, error: string) {
                    if (communityId === root.communityData.id) {
                        Global.displayToastMessage(qsTr("Request to join failed"),
                                                   qsTr("Please try again later"),
                                                   "",
                                                   false,
                                                   Constants.ephemeralNotificationType.normal,
                                                   "")
                    }
                }
            }
        }
    }

    Component {
        id: finaliseCommunityOwnershipBtn

        StatusButton {
            anchors.top: communityHeader.bottom
            anchors.topMargin: Theme.halfPadding
            anchors.bottomMargin: Theme.halfPadding
            anchors.horizontalCenter: parent.horizontalCenter

            text: communityData.joined ? qsTr("Finalise community ownership") : qsTr("To join, finalise community ownership")

            onClicked: root.finaliseOwnershipClicked()
        }
    }

    Component {
        id: createChannelPopup
        CreateChannelPopup {
            communitiesStore: root.communitiesStore
            tokensStore: root.walletAssetsStore.walletTokensStore
            assetsModel: root.store.assetsModel
            collectiblesModel: root.store.collectiblesModel
            ensCommunityPermissionsEnabled: root.ensCommunityPermissionsEnabled
            permissionsModel: {
                root.prepareTokenModelForCommunityChatRequested(communityData.id, chatId)
                return root.spectatedPermissionsModel
            }
            channelsModel: root.store.chatCommunitySectionModule.model
            emojiPopup: root.emojiPopup
            activeCommunity: root.communityData

            property int channelPosition: -1
            property var deleteChatConfirmationDialog

            onCreateCommunityChannel: function (chName, chDescription, chEmoji, chColor,
                                                chCategoryId, viewOnlyCanAddReaction, hideIfPermissionsNotMet) {
                root.store.createCommunityChannel(chName, chDescription, chEmoji, chColor,
                                                  chCategoryId, viewOnlyCanAddReaction, hideIfPermissionsNotMet)
                chatId = root.store.currentChatContentModule().chatDetails.id
            }
            onEditCommunityChannel: {
                root.store.editCommunityChannel(chatId,
                                                chName,
                                                chDescription,
                                                chEmoji,
                                                chColor,
                                                chCategoryId,
                                                channelPosition,
                                                viewOnlyCanAddReaction,
                                                hideIfPermissionsNotMet);
            }

            onAddPermissions: function (permissions) {
                permissions.forEach(p => root.createPermissionRequested(p.holdingsListModel,
                                                                        p.permissionType,
                                                                        p.isPrivate,
                                                                        p.channelsListModel))
            }
            onRemovePermissions: function (permissions) {
                permissions.forEach(p => root.removePermissionRequested(p.id))
            }
            onEditPermissions: function (permissions) {
                permissions.forEach(p => root.editPermissionRequested(p.id,
                                                                      p.holdingsListModel,
                                                                      p.permissionType,
                                                                      p.channelsListModel,
                                                                      p.isPrivate))
            }
            onDeleteCommunityChannel: {
                Global.openPopup(deleteChatConfirmationDialog);
                close()
            }
            onClosed: {
                destroy()
            }
        }
    }

    Component {
        id: createCategoryPopup
        CreateCategoryPopup {
            store: root.store
            onClosed: {
                destroy()
            }
        }
    }

    Component {
        id: deleteCategoryConfirmationDialogComponent
        ConfirmationDialog {
            property string categoryId
            confirmButtonObjectName: "confirmDeleteCategoryButton"
            showCancelButton: true
            onClosed: {
                destroy()
            }
            onCancelButtonClicked: {
                close();
            }
            onConfirmButtonClicked: function(){
                const error = root.store.deleteCommunityCategory(categoryId);
                if (error) {
                    deleteError.text = error
                    return deleteError.open()
                }
                close();
            }
        }
    }

    StatusMessageDialog {
        id: deleteError
        title: qsTr("Error deleting the category")
        icon: StatusMessageDialog.StandardIcon.Critical
    }
}
