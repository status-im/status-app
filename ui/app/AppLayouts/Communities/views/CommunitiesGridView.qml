import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core.Utils

import utils

import QtModelsToolkit
import SortFilterProxyModel

import AppLayouts.Communities.controls
import AppLayouts.Communities.helpers

Flickable {
    id: root

    property var model
    property bool searchLayout: false

    property var assetsModel
    property var collectiblesModel

    property bool compactMode

    readonly property bool isEmpty: !featuredRepeater.count && !root.popularCommunitiesCount
    readonly property int popularCommunitiesCount: firstPopularElementsRepeater.count + restOfPopularElementsRepeater.count

    signal cardClicked(string communityId)

    // Minimal subset of QtQuick.Controls.Control's padding API, since this is a
    // plain Flickable rather than a StatusScrollView/T.ScrollView (see below).
    property real padding: 16
    property real topPadding: padding
    property real bottomPadding: padding
    property real leftPadding: padding
    property real rightPadding: padding

    readonly property real availableWidth: Math.max(0, width - leftPadding - rightPadding)
    readonly property real availableHeight: Math.max(0, height - topPadding - bottomPadding)

    clip: true
    // No horizontal scrolling is ever needed; content padding is applied via
    // contentColumn's x/y offset below instead of contentWidth/contentHeight.
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + topPadding + bottomPadding

    // Plain Flickable (unlike StatusScrollView/T.ScrollView) supports real
    // mouse-drag scrolling out of the box: QQuickScrollView deliberately
    // disables it via childMouseEventFilter, favoring scroll-bar dragging with
    // a physical mouse instead (only touch/touchpad flicking is unaffected).
    // See the equivalent StatusGridView/StatusListView, and the StatusCommunityTagsRow fix in
    // this same issue (#18981), for the established pattern in this codebase.
    boundsBehavior: Flickable.StopAtBounds
    maximumFlickVelocity: 2000
    synchronousDrag: true

    ScrollBar.vertical: StatusScrollBar {
        parent: root
        x: root.width - width - 1
        y: root.topPadding
        height: root.availableHeight
        policy: ScrollBar.AsNeeded
        visible: resolveVisibility(policy, root.availableHeight, root.contentHeight)
    }

    QtObject {
        id: d

        // Values from the design
        readonly property int scrollViewTopMargin: 20
        readonly property int subtitlePixelSize: root.Theme.fontSize(17)
        readonly property int targetDelegateWidth: root.compactMode ? 300 : 335
        property int delegateWidth: targetDelegateWidth

        readonly property int delegateCountPerRow:
            root.availableWidth > 0
            ? Math.max(1, Math.trunc(root.availableWidth / (targetDelegateWidth + root.Theme.padding)))
            : 0

        readonly property int promotionalCardPosition: Math.max(delegateCountPerRow - 1, 1)

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
            enabled: !root.searchLayout
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

            objectName: "communityCard-" + model.name
            // the card root is a plain Rectangle, which Qt does not place in the
            // accessibility tree; a role is required for objectName/name to surface
            Accessible.role: Accessible.Button
            Accessible.name: model.name

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
        x: root.leftPadding
        y: root.topPadding
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
            readonly property int delegateCountPerRow: d.delegateCountPerRow
            Layout.preferredWidth: (delegateCountPerRow * d.delegateWidth) + (spacing * (delegateCountPerRow - 1))
            Layout.alignment: Qt.AlignHCenter

            Layout.topMargin: root.searchLayout
                              ? featuredLabel.height + contentColumn.spacing + featuredLabel.Layout.topMargin
                              : 0

            spacing: Theme.padding
            visible: featuredRepeater.count

            Repeater {
                id: featuredRepeater
                model: featuredModel
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

            readonly property int delegateCountPerRow: d.delegateCountPerRow
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
