import QtQuick
import QtQuick.Layouts

import StatusQ
import StatusQ.Controls
import StatusQ.Core.Theme

import shared.controls
import shared.stores as SharedStores
import utils

import AppLayouts.Chat.stores
import AppLayouts.Communities.layouts
import AppLayouts.Communities.popups

import QtModelsToolkit

SettingsPage {
    id: root

    property int preferredContentWidth: width
    property int internalRightPadding: 0

    property RootStore rootStore

    property var membersModel
    property var bannedMembersModel
    property var pendingMembersModel
    property var declinedMembersModel
    property string communityName

    property int memberRole
    property bool editable: true
    readonly property int contentRightPadding: Math.max(root.headerRightPadding,
                                                        root.width - root.preferredHeaderContentWidth - root.headerRightPadding)

    signal kickUserClicked(string id)
    signal banUserClicked(string id, bool deleteAllMessages)
    signal unbanUserClicked(string id)
    signal acceptRequestToJoin(string id)
    signal declineRequestToJoin(string id)
    signal viewMemberMessagesClicked(string pubKey, string displayName)
    signal inviteNewPeopleClicked()

    function goTo(tab: int) {
        if(root.contentItem) {
            root.contentItem.goTo(tab)
        }
    }

    title: qsTr("Members")

    buttons: [
        StatusButton {
            Layout.fillWidth: true

            text: qsTr("Invite people")
            onClicked: root.inviteNewPeopleClicked()
        }
    ]

    contentItem: ColumnLayout {
        function goTo(tab: int) {
            for (let i = 0; i < membersTabBar.count; i++) {
                const tabButton = membersTabBar.itemAt(i)
                if (tabButton.subSection === tab && tabButton.enabled) {
                    membersTabBar.currentIndex = i
                    return
                }
            }
        }

        spacing: Theme.padding

        StatusTabBar {
            id: membersTabBar

            Layout.fillWidth: true
            Layout.rightMargin: root.contentRightPadding

            StatusTabButton {
                readonly property int subSection: Constants.CommunityMembershipSubSections.Members

                id: allMembersBtn
                objectName: "allMembersButton"
                width: implicitWidth
                text: qsTr("All Members")
            }

            StatusTabButton {
                readonly property int subSection: Constants.CommunityMembershipSubSections.MembershipRequests

                id: pendingRequestsBtn
                objectName: "pendingRequestsButton"
                width: implicitWidth
                text: qsTr("Pending Requests")
                enabled: pendingMembersModel.ModelCount.count > 0
            }

            StatusTabButton {
                readonly property int subSection: Constants.CommunityMembershipSubSections.RejectedMembers

                id: declinedRequestsBtn
                objectName: "declinedRequestsButton"
                width: implicitWidth
                text: qsTr("Rejected")
                enabled: declinedMembersModel.ModelCount.count > 0
            }

            StatusTabButton {
                readonly property int subSection: Constants.CommunityMembershipSubSections.BannedMembers

                id: bannedBtn
                objectName: "bannedButton"
                width: implicitWidth
                enabled: bannedMembersModel.ModelCount.count > 0
                text: qsTr("Banned")
            }
        }

        SearchBox {
            id: memberSearch

            Layout.fillWidth: true
            Layout.rightMargin: root.contentRightPadding

            placeholderText: qsTr("Search by name or chat key")
            enabled: membersTabBar.currentItem.enabled
        }

        MembersTabPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true

            preferredContentWidth: width
            internalRightPadding: root.contentRightPadding

            panelType: membersTabBar.currentItem.subSection
            model: {
                switch (panelType) {
                case Constants.CommunityMembershipSubSections.MembershipRequests:
                    return root.pendingMembersModel
                case Constants.CommunityMembershipSubSections.RejectedMembers:
                    return root.declinedMembersModel
                case Constants.CommunityMembershipSubSections.BannedMembers:
                    return root.bannedMembersModel
                case Constants.CommunityMembershipSubSections.Members:
                default:
                    return root.membersModel
                }
            }

            searchString: memberSearch.text
            rootStore: root.rootStore
            memberRole: root.memberRole

            onKickUserClicked: {
                kickBanPopup.mode = KickBanPopup.Mode.Kick
                kickBanPopup.username = name
                kickBanPopup.userId = id
                kickBanPopup.open()
            }
            onBanUserClicked: {
                kickBanPopup.mode = KickBanPopup.Mode.Ban
                kickBanPopup.username = name
                kickBanPopup.userId = id
                kickBanPopup.open()
            }
            onUnbanUserClicked: root.unbanUserClicked(id)
            onAcceptRequestToJoin: root.acceptRequestToJoin(id)
            onDeclineRequestToJoin: root.declineRequestToJoin(id)
            onViewMemberMessagesClicked: root.viewMemberMessagesClicked(pubKey, displayName)
        }
    }

    KickBanPopup {
        id: kickBanPopup

        property string userId

        communityName: root.communityName

        onBanUserClicked: root.banUserClicked(userId, deleteAllMessages)
        onKickUserClicked: root.kickUserClicked(userId)
    }
}
