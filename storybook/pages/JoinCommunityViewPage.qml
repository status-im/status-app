import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme
import StatusQ.Components

import AppLayouts.Communities.views

import Storybook
import Models

import utils

SplitView {

    QtObject {
        id: d

        // General properties:
        property string name: "Uniswap"
        property string communityDesc: "General channel for the community"
        property string introMessage: "%1 sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo.

1. Ut enim ad minim veniam
2. Excepteur sint occaecat cupidatat non proident
3. Duis aute irure
4. Dolore eu fugiat nulla pariatur
5. 🚗 consectetur adipiscing elit

Nemo enim 😋 ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt.".arg(d.name)

        property color color: "orchid"
        property string channelName: joinCommunity ? "general" : "#vip"
        property string channelDesc: "VIP members only"
        property bool joinCommunity: true // Otherwise it means join channel action
        property int accessType: Constants.communityChatPublicAccess

        // Overlay component:
        property bool requirementsMet: true
        property int requestToJoinState: Constants.RequestToJoinState.None
        property bool isInvitationPending: requestToJoinState !== Constants.RequestToJoinState.None

        property bool isJoinRequestRejected: false
        property bool requiresRequest: false

        property var communityHoldingsModel: PermissionsModel.shortPermissionsModel
        property var viewOnlyHoldingsModel: PermissionsModel.shortPermissionsModel
        property var viewAndPostHoldingsModel: PermissionsModel.shortPermissionsModel
        property var moderateHoldingsModel: PermissionsModel.shortPermissionsModel
        property var assetsModel: AssetsModel {}
        property var collectiblesModel: CollectiblesModel {}

        // Blur background:
        property int membersCount: 184
        property bool amISectionAdmin: false
        property url image: Assets.png("tokens/UNI")
        property var communityItemsModel: model1
        property string chatDateTimeText: "Dec 31, 2020"
        property string  listUsersText: "simon, Mark Cuban "
        readonly property ListModel model1:  ListModel {
            ListElement { name: "welcome"; selected: false; notificationsCount: 0; hasUnreadMessages: false}
            ListElement { name: "general"; selected: false; notificationsCount: 0; hasUnreadMessages: true}
            ListElement { name: "design"; selected: true; notificationsCount: 3; hasUnreadMessages: true}
            ListElement { name: "random"; selected: false; notificationsCount: 0; hasUnreadMessages: false}
            ListElement { name: "vip"; selected: false; notificationsCount: 0; hasUnreadMessages: true}
        }
        readonly property ListModel model2:  ListModel {
            ListElement { name: "general"; selected: false; notificationsCount: 3; hasUnreadMessages: false}
            ListElement { name: "blockchain"; selected: true; notificationsCount: 3; hasUnreadMessages: true}
            ListElement { name: "faq"; selected: false; notificationsCount: 0; hasUnreadMessages: false}
        }
        readonly property var messagesModel: ListModel {
            ListElement {
                timestamp: 1656937930
                senderDisplayName: "simon"
                contentType: StatusMessage.ContentType.Text
                message:  "Hello, this is awesome! Feels like decentralized Discord!"
                isContact: true
                trustIndicator: StatusContactVerificationIcons.TrustedType.Verified
                colorId: 4
            }
            ListElement {
                timestamp: 1657937930
                senderDisplayName: "Mark Cuban"
                contentType: StatusMessage.ContentType.Text
                message: "I know a lot of you really seem to get off or be validated by arguing with strangers online but please know it's a complete waste of your time and energy"
                isContact: false
                trustIndicator: StatusContactVerificationIcons.TrustedType.Untrustworthy
                colorId: 2
            }
        }        
    }

    Logs { id: logs }

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        Rectangle {
            SplitView.fillWidth: true
            SplitView.fillHeight: true
            color: Theme.palette.statusAppLayout.rightPanelBackgroundColor
            clip: true

            JoinCommunityView {
                anchors.fill: parent
                anchors.margins: 50

                // General properties:
                name: d.name
                communityDesc: d.communityDesc
                introMessage: d.introMessage
                color: d.color
                channelName: d.channelName
                channelDesc: d.channelDesc
                joinCommunity: d.joinCommunity
                accessType: d.accessType
                requestToJoinState: d.requestToJoinState

                // Blur background properties:
                membersCount: d.membersCount
                image: d.image                
                amISectionAdmin: d.amISectionAdmin
                communityItemsModel: d.communityItemsModel
                chatDateTimeText: d.chatDateTimeText
                listUsersText: d.listUsersText
                messagesModel: d.messagesModel

                // Permissions properties
                requirementsMet: d.requirementsMet
                isJoinRequestRejected: d.isJoinRequestRejected
                requiresRequest: d.requiresRequest

                communityHoldingsModel: d.communityHoldingsModel
                viewOnlyHoldingsModel: d.viewOnlyHoldingsModel
                viewAndPostHoldingsModel: d.viewAndPostHoldingsModel
                moderateHoldingsModel: d.moderateHoldingsModel
                assetsModel: d.assetsModel
                collectiblesModel: d.collectiblesModel

                onInfoButtonClicked: logs.logEvent("JoinCommunityView::onInfoButtonClicked()")
                onRequestToJoinClicked: logs.logEvent("JoinCommunityView::onRequestToJoinClicked()")
                onInvitationPendingClicked: logs.logEvent("JoinCommunityView::onInvitationPendingClicked()")
            }
        }

        LogsAndControlsPanel {
            id: logsAndControlsPanel

            SplitView.minimumHeight: 100
            SplitView.preferredHeight: 150

            logsView.logText: logs.logText
        }
    }

    Pane {
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 300

        ScrollView {
            anchors.fill: parent

            ColumnLayout {
                spacing: 16

                // Blur info editor:
                Label {
                    Layout.fillWidth: true
                    text: "BLUR INFO EDITOR"
                    font.bold: true
                    font.pixelSize: Theme.fontSize(18)
                }

                CommunityInfoEditor {
                    name: d.name
                    membersCount: d.membersCount
                    amISectionAdmin: d.amISectionAdmin
                    color: d.color
                    image: d.image
                    colorVisible: true

                    onNameChanged: d.name = name
                    onMembersCountChanged: d.membersCount = membersCount
                    onAmISectionAdminChanged: d.amISectionAdmin = amISectionAdmin
                    onColorChanged: d.color = color
                    onImageChanged: d.image = image
                }

                ColumnLayout {
                    Label {
                        Layout.fillWidth: true
                        text: "Community items model:"
                    }

                    RadioButton {
                           checked: true
                           text: qsTr("Model 1")
                           onCheckedChanged: if(checked) d.communityItemsModel =  d.model1
                       }
                       RadioButton {
                           text: qsTr("Model 2")
                            onCheckedChanged: if(checked) d.communityItemsModel = d.model2
                       }
                }

                // Join types:
                Label {
                    Layout.fillWidth: true
                    text: "JOIN TYPES"
                    font.bold: true
                    font.pixelSize: Theme.fontSize(18)
                }

                ColumnLayout {
                    Label {
                        Layout.fillWidth: true
                        text: "Is invitation pending:"
                    }

                    CheckBox {
                        checked: d.isInvitationPending
                        onCheckedChanged: {
                            d.isInvitationPending = checked
                            d.requestToJoinState = d.isInvitationPending ? Constants.RequestToJoinState.Requested : Constants.RequestToJoinState.None
                        }
                    }
                }

                ColumnLayout {
                    visible: d.requestToJoinState === Constants.RequestToJoinState.None
                    Label {
                        Layout.fillWidth: true
                        text: "Access type:"
                    }

                    RadioButton {
                        checked: true
                        text: qsTr("Public access")
                        onCheckedChanged: d.accessType = Constants.communityChatPublicAccess
                    }
                    RadioButton {
                        text: qsTr("On request")
                        onCheckedChanged: d.accessType = Constants.communityChatOnRequestAccess
                    }
                }

                // Join community overlay editor:
                Label {
                    Layout.fillWidth: true
                    text: "JOIN HOLDINGS EDITOR"
                    font.bold: true
                    font.pixelSize: Theme.fontSize(18)
                }

                JoinCommunityPermissionsEditor {
                    channelName: d.chanelName
                    joinCommunity: d.joinCommunity
                    requirementsMet: d.requirementsMet
                    isInvitationPending: d.requestToJoinState !== Constants.RequestToJoinState.None
                    isJoinRequestRejected: d.isJoinRequestRejected
                    requiresRequest: d.requiresRequest

                    onChannelNameChanged: d.channelName = channelName
                    onJoinCommunityChanged: d.joinCommunity = joinCommunity
                    onRequirementsMetChanged: d.requirementsMet = requirementsMet
                    onIsInvitationPendingChanged: d.isInvitationPending = isInvitationPending
                    onIsJoinRequestRejectedChanged: d.isJoinRequestRejected = isJoinRequestRejected
                    onRequiresRequestChanged: d.requiresRequest = requiresRequest
                    onCommunityHoldingsModelChanged: d.communityHoldingsModel = communityHoldingsModel
                    onViewOnlyHoldingsModelChanged: d.viewOnlyHoldingsModel = viewOnlyHoldingsModel
                    onViewAndPostHoldingsModelChanged: d.viewAndPostHoldingsModel = viewAndPostHoldingsModel
                    onModerateHoldingsModelChanged: d.moderateHoldingsModel = moderateHoldingsModel
                }
            }
        }
    }
}

// category: Views

// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=2365%3A317901&t=05yQWHWBWOs2DUTp-0
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=2698%3A380426&t=UOvsb3QLi26KmVrk-0
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba%E2%8E%9CDesktop?node-id=2365%3A291788&t=UOvsb3QLi26KmVrk-0
