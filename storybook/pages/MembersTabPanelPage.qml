import QtCore
import QtQuick

import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Communities.panels
import AppLayouts.Chat.stores as ChatStores
import AppLayouts.stores as AppLayoutStores

import shared.stores
import utils

import Models
import SortFilterProxyModel
import Storybook

import StatusQ

SplitView {
    id: root

    orientation: Qt.Vertical
    Logs { id: logs }

    MembersTabPanel {
        id: membersTabPanelPage

        SplitView.fillWidth: true
        SplitView.fillHeight: true

        internalRightPadding: 20

        model: usersModelWithMembershipState
        panelType: viewStateSelector.currentValue
        searchString: ctrlSearch.text

        rootStore: ChatStores.RootStore {
            contactsStore: AppLayoutStores.ContactsStore {
                readonly property string myPublicKey: "0x000"
            }
        }
        onKickUserClicked: {
            logs.logEvent("MembersTabPanel::onKickUserClicked", ["id", "name"], arguments)
        }

        onBanUserClicked: {
            logs.logEvent("MembersTabPanel::onBanUserClicked", ["id", "name"], arguments)
        }

        onUnbanUserClicked: {
            logs.logEvent("MembersTabPanel::onUnbanUserClicked", ["id"], arguments)
        }

        onAcceptRequestToJoin: {
            logs.logEvent("MembersTabPanel::onAcceptRequestToJoin", ["id"], arguments)
        }

        onDeclineRequestToJoin: {
            logs.logEvent("MembersTabPanel::onDeclineRequestToJoin", ["id"], arguments)
        }

        onViewMemberMessagesClicked: {
            logs.logEvent("MembersTabPanel::onViewMemberMessagesClicked", ["pubKey", "displayName"], arguments)
        }
    }

    UsersModel {
        id: usersModel
    }

    SortFilterProxyModel {
        id: usersModelWithMembershipState
        readonly property var membershipStatePerView: [
            [Constants.CommunityMembershipRequestState.Accepted , Constants.CommunityMembershipRequestState.BannedPending, Constants.CommunityMembershipRequestState.UnbannedPending, Constants.CommunityMembershipRequestState.KickedPending],
            [Constants.CommunityMembershipRequestState.Banned],
            [Constants.CommunityMembershipRequestState.Pending, Constants.CommunityMembershipRequestState.AcceptedPending, Constants.CommunityMembershipRequestState.RejectedPending],
            [Constants.CommunityMembershipRequestState.Rejected]
        ]

        sourceModel: usersModel
        sortRole: membersTabPanelPage.panelType

        proxyRoles: [
            FastExpressionRole {
                name: "membershipRequestState"
                expression: {
                    var memberStates = usersModelWithMembershipState.membershipStatePerView[membersTabPanelPage.panelType]
                    return memberStates[model.index % (memberStates.length)]
                }
                expectedRoles: ["index"]
            },
            ConstantRole {
                name: "requestToJoinLoading"
                value: false
            },
            FastExpressionRole {
                function displayNameProxy(localNickname, ensName, displayName, aliasName) {
                    return ProfileUtils.displayName(localNickname, ensName, displayName, aliasName)
                }

                name: "preferredDisplayName"
                expectedRoles: ["localNickname", "displayName", "ensName", "alias"]
                expression: displayNameProxy(model.localNickname, model.ensName, model.displayName, model.alias)
            }
        ]
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 200
        SplitView.preferredHeight: 320

        logsView.logText: logs.logText

        ColumnLayout {
            Layout.fillWidth: true
            Label {
                text: "View state"
            }

            ComboBox {
                Layout.preferredWidth: 300
                id: viewStateSelector
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: "All members", value: MembersTabPanel.TabType.AllMembers },
                    { text: "Banned Members", value: MembersTabPanel.TabType.BannedMembers },
                    { text: "Pending Members", value: MembersTabPanel.TabType.PendingRequests },
                    { text: "Declined Members", value: MembersTabPanel.TabType.DeclinedRequests },
                ]
            }

            Label { text: "Search" }
            TextField {
                id: ctrlSearch
                Layout.preferredWidth: 300
                placeholderText: "Search by member name or chat key"
            }
        }
    }

    Settings {
        property alias membersTabPanelSelection: viewStateSelector.currentIndex
    }
}

// category: Panels
// status: good
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba⎜Desktop?type=design&node-id=35909-605774&mode=design&t=KfrAekLfW5mTy68x-0
