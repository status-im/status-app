import QtQuick
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Core.Utils

import utils

import QtModelsToolkit
import SortFilterProxyModel

import AppLayouts.Communities.controls
import AppLayouts.Communities.helpers

StatusScrollView {
    id: root

    property var model
    property bool searchLayout: false

    property var assetsModel
    property var collectiblesModel

    property bool compactMode

    readonly property bool isEmpty: !featuredRepeater.count && !root.popularCommunitiesCount
    readonly property int popularCommunitiesCount: firstPopularElementsRepeater.count + restOfPopularElementsRepeater.count

    signal cardClicked(string communityId)

    clip: false
    contentWidth: availableWidth

    QtObject {
        id: d

        // Values from the design
        readonly property int scrollViewTopMargin: 20
        readonly property int subtitlePixelSize: root.Theme.fontSize(17)
        readonly property int promotionalCardPosition: Math.max(gridLayout.delegateCountPerRow - 1, 1)
        property int delegateWidth: root.compactMode ? 300 : 335

        Behavior on delegateWidth {
            PropertyAnimation { duration: ThemeUtils.AnimationDuration.Fast }
        }

        // URLs:
        readonly property string learnAboutCommunitiesVoteLink: Constants.statusHelpLinkPrefix + "communities/vote-to-feature-a-status-community#step-2-initiate-a-round-of-vote"
        readonly property string voteCommunityLink: "https://curate.status.app/votes"
    }

    SortFilterProxyModel {
        id: featuredModel

        sourceModel: root.model

        filters: ValueFilter {
            roleName: "featured"
            value: true
        }
    }

    SortFilterProxyModel {
        id: sfpmFirstPopularElementsModel

        sourceModel: root.model

        filters: [
            ValueFilter {
                roleName: "featured"
                value: false
            },
            IndexFilter {
                maximumIndex: d.promotionalCardPosition - 1
            }
        ]
    }

    SortFilterProxyModel {
        id: sfpmRestOfPopularElementsModel

        sourceModel: root.model

        filters: [
            ValueFilter {
                roleName: "featured"
                value: false
            },
            IndexFilter {
                maximumIndex: d.promotionalCardPosition - 1
                inverted: true
            }
        ]
    }

    Component {
        id: communityCardDelegate

        StatusCommunityCard {
            id: card

            readonly property string tags: model.tags
            readonly property var permissionsList: model.permissionsModel
            readonly property bool isTokenGatedCommunity: PermissionsHelpers.isTokenGatedCommunity(permissionsList)

            JSONListModel {
                id: tagsJson
                json: tags
            }

            width: d.delegateWidth
            communityId: model.id
            loaded: model.available
            asset.source: model.icon
            banner: model.banner
            communityColor: model.color
            name: model.name
            description: model.description
            members: model.members
            activeUsers: model.activeMembers
            popularity: model.popularity
            categories: tagsJson.model
            memberCountVisible: model.joined || !model.encrypted

            // Community restrictions
            Binding {
                target: card
                property: "rigthHeaderComponent"
                when: card.isTokenGatedCommunity
                value: Component {
                    PermissionsRow {
                        readonly property int eligibleToJoinAs: PermissionsHelpers.isEligibleToJoinAs(card.permissionsList)

                        assetsModel: root.assetsModel
                        collectiblesModel: root.collectiblesModel
                        model: card.permissionsList
                        requirementsMet: eligibleToJoinAs === PermissionTypes.Type.Member
                                         || eligibleToJoinAs === PermissionTypes.Type.Admin
                                         || eligibleToJoinAs === PermissionTypes.Type.Owner
                        overlappingBorder: 0
                    }
                }
            }

            onClicked: (communityId) => root.cardClicked(communityId)
        }
    }

    ColumnLayout {
        id: contentColumn
        width: root.availableWidth

        StatusBaseText {
            id: featuredLabel
            visible: !root.searchLayout && featuredRepeater.count
            Layout.topMargin: d.scrollViewTopMargin
            //: Featured communities
            text: qsTr("Featured")
            font.weight: Font.Bold
            font.pixelSize: d.subtitlePixelSize
            color: Theme.palette.directColor1
        }

        Flow {
            readonly property int delegateCountPerRow: Math.trunc(parent.width / (d.delegateWidth + spacing))
            Layout.preferredWidth: (delegateCountPerRow * d.delegateWidth) + (spacing * (delegateCountPerRow - 1))
            Layout.alignment: Qt.AlignHCenter

            Layout.topMargin: root.searchLayout
                              ? featuredLabel.height + contentColumn.spacing + featuredLabel.Layout.topMargin
                              : 0

            spacing: Theme.padding
            visible: featuredRepeater.count

            Repeater {
                id: featuredRepeater
                model: root.searchLayout ? root.model : featuredModel
                delegate: communityCardDelegate
            }
            move: FastXYTransition {}
            add: FastXYZeroTransition {}
        }

        StatusBaseText {
            visible: !root.searchLayout && root.popularCommunitiesCount
            Layout.topMargin: 20
            //: All communities
            text: qsTr("All")
            font.weight: Font.Bold
            font.pixelSize: d.subtitlePixelSize
            color: Theme.palette.directColor1
        }

        Flow {
            id: gridLayout

            readonly property int delegateCountPerRow: Math.trunc(parent.width / (d.delegateWidth + spacing))
            Layout.preferredWidth: (delegateCountPerRow * d.delegateWidth) + (spacing * (delegateCountPerRow - 1))
            Layout.alignment: Qt.AlignHCenter

            visible: !root.searchLayout
            
            spacing: Theme.padding

            Repeater {
                id: firstPopularElementsRepeater
                model: sfpmFirstPopularElementsModel
                delegate: communityCardDelegate
            }

            PromotionalCommunityCard {
                width: d.delegateWidth

                onLearnMore: Global.requestOpenLink(d.learnAboutCommunitiesVoteLink)
                onInitiateVote: Global.requestOpenLink(d.voteCommunityLink)
            }

            Repeater {
                id: restOfPopularElementsRepeater
                model: sfpmRestOfPopularElementsModel
                delegate: communityCardDelegate
            }
            move: FastXYTransition {}
            add: FastXYZeroTransition {}
        }

        StatusBaseText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.xlPadding * 2
            width: d.delegateWidth
            visible: root.model.ModelCount.empty
            text: qsTr("No communities found")
            color: Theme.palette.baseColor1
        }
    }

    component FastXYTransition: Transition {
        NumberAnimation { properties: "x,y"; duration: ThemeUtils.AnimationDuration.Fast}
    }
    component FastXYZeroTransition: Transition {
        NumberAnimation { properties: "x,y"; from: 0; duration: ThemeUtils.AnimationDuration.Fast}
    }
}
