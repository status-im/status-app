import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls

import shared
import shared.controls
import shared.views.chat
import utils

import SortFilterProxyModel

ColumnLayout {
    id: root

    property var usersModel
    // (pubKey) -> emoji hash array, fetched when a member's context menu opens
    property var getEmojiHashFn: pubKey => []

    property bool headerVisible: true
    property string searchText: searchField.text

    property string label
    property int chatType: Constants.chatType.unknown
    property bool isAdmin
    property int communityMemberReevaluationStatus: Constants.CommunityMemberReevaluationStatus.None

    signal openProfileRequested(string pubKey)
    signal createOneToOneChatRequested(string pubKey)
    signal reviewContactRequestRequested(string pubKey)
    signal sendContactRequestRequested(string pubKey)
    signal editNicknameRequested(string pubKey)
    signal removeNicknameRequested(string pubKey)
    signal blockContactRequested(string pubKey)
    signal unblockContactRequested(string pubKey)
    signal markAsTrustedRequested(string pubKey)
    signal markAsUntrustedRequested(string pubKey)
    signal removeTrustStatusRequested(string pubKey)
    signal removeTrustedMarkRequested(string pubKey)
    signal removeContactRequested(string pubKey)
    signal removeContactFromGroupRequested(string pubKey)

    spacing: Theme.halfPadding

    QtObject {
        id: d

        readonly property int delegateHorizontalPadding: Math.max(Theme.halfPadding, 8)
        readonly property int scrollBarWidth: Math.max(Theme.halfPadding, 8)
    }

    MembersPanelHeader {
        id: header
        Layout.fillWidth: true
        Layout.margins: Theme.padding
        visible: root.headerVisible
        label: root.label
    }

    SearchBox {
        id: searchField
        objectName: "membersSearchBox"
        KeyNavigation.tab: userListView
        Keys.onEscapePressed: header.searchChecked = false
        Layout.fillWidth: true
        Layout.leftMargin: Theme.padding
        Layout.rightMargin: Theme.padding
        placeholderText: qsTr("Search members...")
        visible: root.headerVisible && header.searchChecked
        onVisibleChanged: {
            if (visible)
                forceActiveFocus()
            else
                clear()
        }
    }

    StatusBaseText {
        id: communityMemberReevaluationInProgressText
        Layout.fillWidth: true
        Layout.leftMargin: Theme.padding
        Layout.rightMargin: Theme.padding
        visible: root.communityMemberReevaluationStatus === Constants.CommunityMemberReevaluationStatus.InProgress
        font.pixelSize: Theme.secondaryTextFontSize
        text: qsTr("Member re-evaluation in progress...")
        wrapMode: Text.WordWrap

        StatusToolTip {
            text: qsTr("Saving community edits might take longer than usual")
            visible: hoverHandler.hovered
        }
        HoverHandler {
            id: hoverHandler
            enabled: communityMemberReevaluationInProgressText.visible
        }
    }

    StatusListView {
        id: userListView
        objectName: "userListPanel"

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: Theme.padding
        Layout.rightMargin: 0

        verticalScrollBar.implicitWidth: d.scrollBarWidth
        verticalScrollBar.width: d.scrollBarWidth

        // Rows keep the model's order (online first, then by name, sorted in Nim)
        model: SortFilterProxyModel {
            sourceModel: root.usersModel
            filters: [
                SQUtils.SearchFilter {
                    roleName: "preferredDisplayName"
                    searchPhrase: root.searchText
                    enabled: !!root.searchText
                }
            ]
        }
        section.property: "onlineStatus"
        section.delegate: (root.width > 58) ? sectionDelegateComponent : null
        delegate: StatusMemberListItem {
            // Keep equal panel margins, with the scrollbar in the right gutter.
            width: Math.max(0, ListView.view.width - Theme.padding)
            horizontalPadding: d.delegateHorizontalPadding

            usesDefaultName: model.usesDefaultName
            nickName: model.localNickname
            userName: ProfileUtils.displayName("", model.ensName, model.displayName, model.alias)
            pubKey: model.isEnsVerified ? "" : model.compressedPubKey
            isContact: model.isContact
            isVerified: model.isVerified
            isUntrustworthy: model.isUntrustworthy
            isBlocked: model.isBlocked
            isOwner: model.memberRole === Constants.memberRole.owner
            icon.name: model.icon
            icon.color: Utils.colorForColorId(Theme.palette, model.colorId)
            status: model.onlineStatus

            onClicked: {
                console.warn("!!! CLICK")
                Global.openProfilePopup(model.pubKey)
            }
            onRightClicked: position => {
                console.warn("!!! RIGHT CLICK")
                const profileType = Utils.getProfileType(model.isCurrentUser, false, model.isBlocked)
                const contactType = Utils.getContactType(model.contactRequest, model.isContact)

                const params = {
                    profileType, contactType,
                    pubKey: model.pubKey,
                    compressedPubKey: model.compressedPubKey,
                    emojiHash: root.getEmojiHashFn(model.pubKey),
                    colorId: model.colorId,
                    displayName: model.preferredDisplayName,
                    userIcon: model.icon,
                    trustStatus: model.trustStatus,
                    onlineStatus: model.onlineStatus,
                    hasLocalNickname: !!model.localNickname,
                    usesDefaultName: model.usesDefaultName,
                    chatType: root.chatType,
                    isAdmin: root.isAdmin
                }

                Global.openMenu(profileContextMenuComponent, this, params, position)
            }
        }
    }

    Component {
        id: sectionDelegateComponent

        Item {
            width: Math.max(0, ListView.view.width - Theme.padding)
            height: 24

            StatusBaseText {
                anchors.fill: parent
                anchors.leftMargin: d.delegateHorizontalPadding
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Theme.additionalTextSize
                color: Theme.palette.baseColor1
                text: {
                    switch(parseInt(section)) {
                        case Constants.onlineStatus.online:
                            return qsTr("Online")
                        default:
                            return qsTr("Inactive")
                    }
                }
            }
        }
    }

    Component {
        id: profileContextMenuComponent

        ProfileContextMenu {
            property string pubKey

            margins: Theme.halfPadding

            onOpenProfileClicked: root.openProfileRequested(pubKey)
            onCreateOneToOneChat: root.createOneToOneChatRequested(pubKey)
            onReviewContactRequest: root.reviewContactRequestRequested(pubKey)
            onSendContactRequest: root.sendContactRequestRequested(pubKey)
            onEditNickname: root.editNicknameRequested(pubKey)
            onRemoveNickname: root.removeNicknameRequested(pubKey)
            onUnblockContact: root.unblockContactRequested(pubKey)
            onMarkAsUntrusted: root.markAsUntrustedRequested(pubKey)
            onRemoveTrustStatus: root.removeTrustStatusRequested(pubKey)
            onRemoveContact: root.removeContactRequested(pubKey)
            onBlockContact: root.blockContactRequested(pubKey)
            onRemoveFromGroup: root.removeContactFromGroupRequested(pubKey)
            onMarkAsTrusted: root.markAsTrustedRequested(pubKey)
            onRemoveTrustedMark: root.removeTrustedMarkRequested(pubKey)

            onClosed: destroy()
        }
    }
}
