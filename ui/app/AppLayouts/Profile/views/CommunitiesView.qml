import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls

import utils

import SortFilterProxyModel
import QtModelsToolkit

import AppLayouts.Profile.panels
import AppLayouts.stores as AppLayoutsStores

SettingsContentBase {
    id: root

    property AppLayoutsStores.RootStore rootStore

    property var communitiesList
    property var fnIsMyCommunityRequestPending: function(communityId) {}

    signal leaveCommunityRequest(string communityId)
    signal setCommunityMutedRequest(string communityId, int mutedType)
    signal inviteFriends(var communityData)
    signal cancelPendingRequestRequested(string communityId)

    titleRowComponentLoader.sourceComponent: StatusButton {
        text: qsTr("Import community")
        size: StatusBaseButton.Size.Small
        onClicked: Global.importCommunityPopupRequested()
    }

    Item {
        id: rootItem
        width: root.contentWidth
        height: childrenRect.height

        ColumnLayout {
            id: noCommunitiesLayout
            anchors.fill: parent
            visible: root.communitiesList.ModelCount.empty
            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop

            Image {
                source: Assets.png("settings/communities")
                mipmap: true
                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                Layout.preferredWidth: 434
                Layout.preferredHeight: 213
                Layout.topMargin: 18
                cache: false
            }

            StatusBaseText {
                text: qsTr("Discover your Communities")
                color: Theme.palette.directColor1
                wrapMode: Text.WordWrap
                font.weight: Font.Bold
                font.pixelSize: Theme.secondaryAdditionalTextSize
                Layout.topMargin: 35

                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            }

            StatusBaseText {
                text: qsTr("Explore and see what communities are trending")
                color: Theme.palette.baseColor1
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.primaryTextFontSize
                Layout.topMargin: 8
                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            }

            StatusButton {
                text: qsTr("Discover")
                Layout.topMargin: 16
                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                onClicked: Global.changeAppSectionBySectionType(Constants.appSection.communitiesPortal)
            }
        }

        Column {
            id: rootLayout
            visible: !noCommunitiesLayout.visible
            width: parent.width
            anchors.top: parent.top
            anchors.left: parent.left
            spacing: Theme.padding

            Heading {
                text: qsTr("Owner")
                visible: panelOwners.count
            }

            Panel {
                id: panelOwners
                filters: ValueFilter {
                    readonly property int role: Constants.memberRole.owner
                    roleName: "memberRole"
                    value: role
                }
            }

            Heading {
                text: qsTr("TokenMaster")
                visible: panelTokenMasters.count
            }

            Panel {
                id: panelTokenMasters
                filters: ValueFilter {
                    readonly property int role: Constants.memberRole.tokenMaster
                    roleName: "memberRole"
                    value: role
                }
            }

            Heading {
                text: qsTr("Admin")
                visible: panelAdmins.count
            }

            Panel {
                id: panelAdmins
                filters: ValueFilter {
                    readonly property int role: Constants.memberRole.admin
                    roleName: "memberRole"
                    value: role
                }
            }

            Heading {
                text: qsTr("Member")
                visible: panelMembers.count
            }

            Panel {
                id: panelMembers
                filters: AllOf {
                    ValueFilter {
                        roleName: "joined"
                        value: true
                    }
                    ValueFilter {
                        roleName: "memberRole"
                        value: Constants.memberRole.none
                    }
                }
            }

            Heading {
                text: qsTr("Pending")
                visible: panelPendingRequests.count
            }

            Panel {
                id: panelPendingRequests
                filters: AllOf {
                    ValueFilter {
                        roleName: "spectated"
                        value: true
                    }
                    ValueFilter {
                        roleName: "joined"
                        value: false
                    }
                }
            }
        }
    }

    component Heading: StatusBaseText {
        anchors.left: parent.left
        anchors.leftMargin: Theme.padding
        color: Theme.palette.baseColor1
    }

    component Panel: CommunitiesListPanel {
        id: panel

        property var filters

        width: parent.width
        compactMode: root.contentWidth < 560
        fnIsMyCommunityRequestPending: root.fnIsMyCommunityRequestPending

        model: SortFilterProxyModel {
            sourceModel: root.communitiesList
            filters: panel.filters
        }

        onCloseCommunityClicked: communityId => {
            root.leaveCommunityRequest(communityId)
        }

        onLeaveCommunityClicked: (community, communityId, outroMessage) => {
            Global.leaveCommunityRequested(community, communityId, outroMessage)
        }

        onSetCommunityMutedClicked: (communityId, mutedType) => {
            root.setCommunityMutedRequest(communityId, mutedType)
        }

        onSetActiveCommunityClicked: communityId => {
            root.rootStore.setActiveCommunity(communityId)
        }

        onInviteFriends: communityData => root.inviteFriends(communityData)

        onShowCommunityMembershipSetupDialog: (communityId, name, introMessage, imageSrc, accessType) => {
            Global.communityIntroPopupRequested(communityId, name, introMessage, imageSrc, root.fnIsMyCommunityRequestPending(communityId))
        }
        onCancelMembershipRequest: communityId => {
            root.cancelPendingRequestRequested(communityId)
        }
    }
}
