import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups

import shared
import shared.controls.chat
import shared.controls.delegates
import shared.stores as SharedStores
import shared.views.chat
import utils

import AppLayouts.Chat.stores

import SortFilterProxyModel

Item {
    id: root

    required property var model

    property int preferredContentWidth: width
    property int internalRightPadding: 0

    property string searchString
    property RootStore rootStore

    property int panelType: MembersTabPanel.TabType.AllMembers
    property int memberRole: Constants.memberRole.none

    readonly property bool isOwner: memberRole === Constants.memberRole.owner
    readonly property bool isTokenMaster: memberRole === Constants.memberRole.tokenMaster

    signal kickUserClicked(string id, string name)
    signal banUserClicked(string id, string name)
    signal unbanUserClicked(string id)
    signal viewMemberMessagesClicked(string pubKey, string displayName)

    signal acceptRequestToJoin(string id)
    signal declineRequestToJoin(string id)

    enum TabType {
        AllMembers,
        BannedMembers,
        PendingRequests,
        DeclinedRequests
    }

    StatusListView {
        objectName: "CommunityMembersTabPanel_MembersListViews"
        anchors.fill: parent

        model: SortFilterProxyModel {
            sourceModel: root.model

            sorters: StringSorter {
                roleName: "preferredDisplayName"
                caseSensitivity: Qt.CaseInsensitive
            }

            filters: UserSearchFilter {
                searchString: root.searchString
            }
        }

        spacing: 0

        delegate: ContactListItemDelegate {
            id: memberItem

            // Buttons visibility conditions:
            // 1. Tab based buttons - only visible when the tab is selected
            //      a. All members tab
            //          - Kick; - Kick pending
            //          - Ban; - Ban pending
            //      b. Pending requests tab
            //          - Accept; - Accept pending
            //          - Reject; - Reject pending
            //      c. Rejected members tab
            //          - Accept; - Accept pending
            //      d. Banned members tab
            //          - Unban
            // 2. Pending states - buttons in pending states are always visible in their specific tab. Other buttons are disabled if the request is in pending state
            //    - Accept button is visible when the user is hovered or when the request is in accepted pending state. This condition can be overriden by the ctaAllowed property
            //    - Reject button is visible when the user is hovered or when the request is in rejected pending state. This condition can be overriden by the ctaAllowed property
            //    - Kick and ban buttons are visible when the user is hovered or when the request is in kick or ban pending state. This condition can be overriden by the ctaAllowed property
            // 3. Other conditions - buttons are visible when the user is hovered and is not himself or other privileged user
            // 4. All members tab, member in AwaitingAddress state - buttons is not visible, sandwatch icon is shown

            /// Helpers ///

            // Tab based buttons
            readonly property bool tabIsShowingKickBanButtons: root.panelType === MembersTabPanel.TabType.AllMembers
            readonly property bool tabIsShowingUnbanButton: root.panelType === MembersTabPanel.TabType.BannedMembers
            readonly property bool tabIsShowingRejectButton: root.panelType === MembersTabPanel.TabType.PendingRequests
            readonly property bool tabIsShowingAcceptButton: root.panelType === MembersTabPanel.TabType.PendingRequests ||
                                                             root.panelType === MembersTabPanel.TabType.DeclinedRequests
            readonly property bool tabIsShowingViewMessagesButton: model.membershipRequestState !== Constants.CommunityMembershipRequestState.BannedWithAllMessagesDelete &&
                                                                   (root.panelType === MembersTabPanel.TabType.AllMembers ||
                                                                    root.panelType === MembersTabPanel.TabType.BannedMembers)


            // Request states
            readonly property bool isPending: model.membershipRequestState === Constants.CommunityMembershipRequestState.Pending
            readonly property bool isAccepted: model.membershipRequestState === Constants.CommunityMembershipRequestState.Accepted
            readonly property bool isRejected: model.membershipRequestState === Constants.CommunityMembershipRequestState.Rejected
            readonly property bool isRejectedPending: model.membershipRequestState === Constants.CommunityMembershipRequestState.RejectedPending
            readonly property bool isAcceptedPending: model.membershipRequestState === Constants.CommunityMembershipRequestState.AcceptedPending
            readonly property bool isBanPending: model.membershipRequestState === Constants.CommunityMembershipRequestState.BannedPending
            readonly property bool isUnbanPending: model.membershipRequestState === Constants.CommunityMembershipRequestState.UnbannedPending
            readonly property bool isKickPending: model.membershipRequestState === Constants.CommunityMembershipRequestState.KickedPending
            readonly property bool isBanned: model.membershipRequestState === Constants.CommunityMembershipRequestState.Banned ||
                                             model.membershipRequestState === Constants.CommunityMembershipRequestState.BannedWithAllMessagesDelete
            readonly property bool isKicked: model.membershipRequestState === Constants.CommunityMembershipRequestState.Kicked

            // TODO: Connect to backend when available
            // The admin that initited the pending state can change the state. Actions are not visible for other admins
            readonly property bool ctaAllowed: !isRejectedPending && !isAcceptedPending && !isBanPending && !isUnbanPending && !isKickPending

            readonly property bool canBeBanned: {
                if (model.isCurrentUser)
                    return false

                switch (model.memberRole) {
                    // Owner can't be banned
                case Constants.memberRole.owner: return false
                    // TokenMaster can only be banned by owner
                case Constants.memberRole.tokenMaster: return root.isOwner
                    // Admin can only be banned by owner and tokenMaster
                case Constants.memberRole.admin: return root.isOwner || root.isTokenMaster
                    // All normal members can be banned by all privileged users
                default: return true
                }
            }
            readonly property bool showOnHover: hovered && ctaAllowed
            readonly property bool canDeleteMessages: model.isCurrentUser || model.memberRole !== Constants.memberRole.owner

            /// Button visibility ///
            readonly property bool acceptButtonVisible: tabIsShowingAcceptButton && (isPending || isRejected || isRejectedPending || isAcceptedPending) && showOnHover
            readonly property bool rejectButtonVisible: tabIsShowingRejectButton && (isPending || isRejectedPending || isAcceptedPending) && showOnHover
            readonly property bool acceptPendingButtonVisible: tabIsShowingAcceptButton && isAcceptedPending
            readonly property bool rejectPendingButtonVisible: tabIsShowingRejectButton && isRejectedPending
            readonly property bool kickButtonVisible: tabIsShowingKickBanButtons && isAccepted && showOnHover && canBeBanned
            readonly property bool banButtonVisible: tabIsShowingKickBanButtons && isAccepted && showOnHover && canBeBanned
            readonly property bool kickPendingButtonVisible: tabIsShowingKickBanButtons && isKickPending
            readonly property bool banPendingButtonVisible: tabIsShowingKickBanButtons && isBanPending
            readonly property bool unbanButtonVisible: tabIsShowingUnbanButton && isBanned && showOnHover
            readonly property bool viewMessagesButtonVisible: tabIsShowingViewMessagesButton && showOnHover
            readonly property bool messagesDeletedTextVisible: showOnHover &&
                                                               model.membershipRequestState === Constants.CommunityMembershipRequestState.BannedWithAllMessagesDelete

            /// Pending states ///
            readonly property bool isPendingState: isAcceptedPending || isRejectedPending || isBanPending || isUnbanPending || isKickPending
            readonly property string pendingStateText: isAcceptedPending ? qsTr("Accept pending...") :
                                                                           isRejectedPending ? qsTr("Reject pending...") :
                                                                                               isBanPending ? qsTr("Ban pending...") :
                                                                                                              isUnbanPending ? qsTr("Unban pending...") :
                                                                                                                               isKickPending ? qsTr("Kick pending...") : ""

            isAwaitingAddress: model.membershipRequestState === Constants.CommunityMembershipRequestState.AwaitingAddress

            components: [
                StatusBaseText {
                    id: pendingText
                    width: Math.max(implicitWidth, d.pendingTextMaxWidth)
                    onImplicitWidthChanged: {
                        d.pendingTextMaxWidth = Math.max(implicitWidth, d.pendingTextMaxWidth)
                    }
                    visible: !!text && isPendingState
                    rightPadding: isKickPending || isBanPending || isUnbanPending ? 0 : Theme.bigPadding
                    anchors.verticalCenter: parent.verticalCenter
                    text: pendingStateText
                    color: Theme.palette.baseColor1
                    StatusToolTip {
                        text: qsTr("Waiting for owner node to come online")
                        visible: hoverHandler.hovered
                    }
                    HoverHandler {
                        id: hoverHandler
                        enabled: pendingText.visible
                    }
                },

                StatusBaseText {
                    text: qsTr("Messages deleted")
                    color: Theme.palette.baseColor1
                    anchors.verticalCenter: parent.verticalCenter
                    visible: messagesDeletedTextVisible
                },

                StatusButton {
                    id: viewMessages
                    anchors.verticalCenter: parent.verticalCenter
                    objectName: "MemberListItem_ViewMessages"
                    text: qsTr("View Messages")
                    visible: viewMessagesButtonVisible
                    size: StatusBaseButton.Size.Small
                    onClicked: root.viewMemberMessagesClicked(model.pubKey, memberItem.title)
                },

                StatusButton {
                    anchors.verticalCenter: parent.verticalCenter
                    objectName: "MemberListItem_KickButton"
                    text: qsTr("Kick")
                    visible: kickButtonVisible
                    type: StatusBaseButton.Type.Danger
                    size: StatusBaseButton.Size.Small
                    onClicked: root.kickUserClicked(model.pubKey, memberItem.title)
                },

                StatusButton {
                    objectName: "MemberListItem_BanButton"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: banButtonVisible
                    text: qsTr("Ban")
                    type: StatusBaseButton.Type.Danger
                    size: StatusBaseButton.Size.Small
                    onClicked: root.banUserClicked(model.pubKey, memberItem.title)
                },

                StatusButton {
                    objectName: "MemberListItem_UnbanButton"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: unbanButtonVisible
                    text: qsTr("Unban")
                    type: StatusBaseButton.Type.Danger
                    size: StatusBaseButton.Size.Small
                    onClicked: root.unbanUserClicked(model.pubKey)
                },

                StatusButton {
                    id: acceptButton
                    objectName: "MemberListItem_AcceptButton"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: acceptButtonVisible
                    text: qsTr("Accept")
                    type: StatusBaseButton.Type.Success
                    size: StatusBaseButton.Size.Small
                    icon.name: "checkmark-circle"
                    icon.color: enabled ? Theme.palette.successColor1 : disabledTextColor
                    loading: model.requestToJoinLoading
                    enabled: !acceptPendingButtonVisible
                    onClicked: root.acceptRequestToJoin(model.requestToJoinId)
                },

                StatusButton {
                    id: rejectButton
                    objectName: "MemberListItem_RejectButton"
                    visible: rejectButtonVisible
                    text: qsTr("Reject")
                    type: StatusBaseButton.Type.Danger
                    size: StatusBaseButton.Size.Small
                    icon.name: "close-circle"
                    icon.color: enabled ? Theme.palette.dangerColor1 : disabledTextColor
                    enabled: !rejectPendingButtonVisible
                    onClicked: root.declineRequestToJoin(model.requestToJoinId)
                }
            ]

            readonly property string title: model.preferredDisplayName

            width: Math.min(ListView.view.width - root.internalRightPadding,
                            root.preferredContentWidth)

            icon.width: 40
            icon.height: 40

            onClicked: Global.openProfilePopup(model.pubKey)
            onRightClicked: {
                const profileType = Utils.getProfileType(model.isCurrentUser, false, model.isBlocked)
                const contactType = Utils.getContactType(model.contactRequest, model.isContact)

                const params = {
                    profileType, contactType,
                    pubKey: model.pubKey,
                    compressedPubKey: model.compressedPubKey,
                    emojiHash: JSON.parse(model.emojiHash),
                    colorId: model.colorId,
                    displayName: memberItem.title || model.displayName,
                    userIcon: model.icon,
                    trustStatus: model.trustStatus,
                    onlineStatus: model.onlineStatus,
                    ensVerified: model.isEnsVerified,
                    hasLocalNickname: !!model.localNickname,
                    usesDefaultName: model.usesDefaultName
                }

                memberContextMenuComponent.createObject(root, params).popup(this)
            }
        }

        Component {
            id: memberContextMenuComponent

            ProfileContextMenu {
                id: memberContextMenuView

                required property string pubKey

                onOpenProfileClicked: Global.openProfilePopup(pubKey, null)
                onCreateOneToOneChat: {
                    Global.changeAppSectionBySectionType(Constants.appSection.chat)
                    root.rootStore.chatCommunitySectionModule.createOneToOneChat("", pubKey, "")
                }
                onReviewContactRequest: Global.openReviewContactRequestPopup(pubKey, null)
                onSendContactRequest: Global.openContactRequestPopup(pubKey, null)
                onEditNickname: Global.openNicknamePopupRequested(pubKey, null)
                onRemoveNickname: root.rootStore.contactsStore.changeContactNickname(pubKey, "", displayName, true)
                onUnblockContact: Global.unblockContactRequested(pubKey)
                onMarkAsUntrusted: Global.markAsUntrustedRequested(pubKey)
                onRemoveTrustStatus: root.rootStore.contactsStore.removeTrustStatus(pubKey)
                onRemoveContact: Global.removeContactRequested(pubKey)
                onBlockContact: Global.blockContactRequested(pubKey)
                onMarkAsTrusted: Global.openMarkAsIDVerifiedPopup(pubKey, null)
                onRemoveTrustedMark: Global.openRemoveIDVerificationDialog(pubKey, null)
                onClosed: destroy()
            }
        }
    }

    QtObject {
        id: d
        // This is used to calculate the max width of the pending text
        // so that the text aligned on all rows (the text might be different on each row)
        property real pendingTextMaxWidth: 0
    }

    onPanelTypeChanged: { d.pendingTextMaxWidth = 0 }
}
