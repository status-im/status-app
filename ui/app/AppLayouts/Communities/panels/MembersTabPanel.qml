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
            // 2. Pending states - pending labels are always visible in their specific tab.
            //    Actions remain visible while a request action is loading or when ctaAllowed is true
            // 3. Other conditions - actions are hidden for current user and privileged users that cannot be banned
            // 4. All members tab, member in AwaitingAddress state - buttons are not visible, sandwatch icon is shown

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
            readonly property bool showActions: ctaAllowed
            readonly property bool canDeleteMessages: model.isCurrentUser || model.memberRole !== Constants.memberRole.owner

            /// Button visibility ///
            readonly property bool acceptButtonVisible: tabIsShowingAcceptButton && (isPending || isRejected || isRejectedPending || isAcceptedPending) && showActions
            readonly property bool rejectButtonVisible: tabIsShowingRejectButton && (isPending || isRejectedPending || isAcceptedPending) && showActions
            readonly property bool acceptPendingButtonVisible: tabIsShowingAcceptButton && isAcceptedPending
            readonly property bool rejectPendingButtonVisible: tabIsShowingRejectButton && isRejectedPending
            readonly property bool kickButtonVisible: tabIsShowingKickBanButtons && isAccepted && showActions && canBeBanned
            readonly property bool banButtonVisible: tabIsShowingKickBanButtons && isAccepted && showActions && canBeBanned
            readonly property bool kickPendingButtonVisible: tabIsShowingKickBanButtons && isKickPending
            readonly property bool banPendingButtonVisible: tabIsShowingKickBanButtons && isBanPending
            readonly property bool unbanButtonVisible: tabIsShowingUnbanButton && isBanned && showActions
            readonly property bool viewMessagesButtonVisible: tabIsShowingViewMessagesButton && showActions
            readonly property bool messagesDeletedTextVisible: showActions && model.membershipRequestState === Constants.CommunityMembershipRequestState.BannedWithAllMessagesDelete

            /// Pending states ///
            readonly property bool isPendingState: isAcceptedPending || isRejectedPending || isBanPending || isUnbanPending || isKickPending
            readonly property string pendingStateText: isAcceptedPending ? qsTr("Accept pending") :
                                                                           isRejectedPending ? qsTr("Reject pending") :
                                                                                               isBanPending ? qsTr("Ban pending") :
                                                                                                              isUnbanPending ? qsTr("Unban pending") :
                                                                                                                               isKickPending ? qsTr("Kick pending") : ""

            isAwaitingAddress: model.membershipRequestState === Constants.CommunityMembershipRequestState.AwaitingAddress
            components: [
                RowLayout {
                    visible: isPendingState
                    spacing: Theme.halfPadding

                    StatusBaseText {
                        Layout.alignment: Qt.AlignVCenter
                        font.pixelSize: Theme.additionalTextFontSize
                        text: pendingStateText
                        color: Theme.palette.baseColor1
                    }

                    StatusIcon {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        icon: "tiny/in-progress"
                    }

                    StatusToolTip {
                        text: qsTr("Waiting for owner node to come online")
                        visible: pendingHoverHandler.hovered
                    }
                    HoverHandler {
                        id: pendingHoverHandler
                        enabled: parent.visible
                    }
                },

                StatusBaseText {
                    text: qsTr("Messages deleted")
                    color: Theme.palette.baseColor1
                    visible: messagesDeletedTextVisible
                },

                StatusButton {
                    id: viewMessages
                    objectName: "MemberListItem_ViewMessages"
                    text: qsTr("View messages")
                    visible: viewMessagesButtonVisible
                    Layout.fillWidth: true
                    size: StatusBaseButton.Size.Tiny
                    horizontalPadding: d.buttonPadding
                    verticalPadding: d.buttonPadding
                    onClicked: root.viewMemberMessagesClicked(model.pubKey, memberItem.title)
                },

                StatusButton {
                    objectName: "MemberListItem_KickButton"
                    text: qsTr("Kick")
                    visible: kickButtonVisible
                    type: StatusBaseButton.Type.Danger
                    Layout.fillWidth: true
                    size: StatusBaseButton.Size.Tiny
                    horizontalPadding: d.buttonPadding
                    verticalPadding: d.buttonPadding
                    onClicked: root.kickUserClicked(model.pubKey, memberItem.title)
                },

                StatusButton {
                    objectName: "MemberListItem_BanButton"
                    visible: banButtonVisible
                    text: qsTr("Ban")
                    type: StatusBaseButton.Type.Danger
                    Layout.fillWidth: true
                    size: StatusBaseButton.Size.Tiny
                    horizontalPadding: d.buttonPadding
                    verticalPadding: d.buttonPadding
                    onClicked: root.banUserClicked(model.pubKey, memberItem.title)
                },

                StatusButton {
                    objectName: "MemberListItem_UnbanButton"
                    visible: unbanButtonVisible
                    text: qsTr("Unban")
                    type: StatusBaseButton.Type.Danger
                    Layout.fillWidth: true
                    size: StatusBaseButton.Size.Tiny
                    horizontalPadding: d.buttonPadding
                    verticalPadding: d.buttonPadding
                    onClicked: root.unbanUserClicked(model.pubKey)
                },

                StatusButton {
                    id: acceptButton
                    objectName: "MemberListItem_AcceptButton"
                    visible: acceptButtonVisible
                    text: qsTr("Accept")
                    Layout.fillWidth: true
                    size: StatusBaseButton.Size.Tiny
                    horizontalPadding: d.buttonPadding
                    verticalPadding: d.buttonPadding
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
                    Layout.fillWidth: true
                    size: StatusBaseButton.Size.Tiny
                    horizontalPadding: d.buttonPadding
                    verticalPadding: d.buttonPadding
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
        readonly property real buttonPadding: Math.max(root.Theme.halfPadding, 8)
    }
}
