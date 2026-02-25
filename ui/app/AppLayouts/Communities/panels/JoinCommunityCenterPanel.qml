import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Layout

import utils

ColumnLayout {
    id: root

    property bool joinCommunity: true // Otherwise it means join channel action
    property bool allChannelsAreHiddenBecauseNotPermitted: false

    property string name
    property string channelName

    property int requestToJoinState: Constants.RequestToJoinState.None
    property bool isJoinRequestRejected: false
    property bool requiresRequest: false

    property bool requirementsMet: true
    property bool requirementsCheckPending: false
    property bool missingEncryptionKey: false

    property var communityHoldingsModel
    property var viewOnlyHoldingsModel
    property var viewAndPostHoldingsModel
    property var moderateHoldingsModel
    property var assetsModel
    property var collectiblesModel

    property string chatDateTimeText
    property string listUsersText
    property var messagesModel

    signal requestToJoinClicked
    signal invitationPendingClicked

    spacing: 0

    // Blur background:
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(
                                    centralPanelData.implicitHeight,
                                    parent.height - overlayPanel.implicitHeight)

        ColumnLayout {
            id: centralPanelData
            width: parent.width
            layer.enabled: true
            layer.effect: fastBlur

            StatusBaseText {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 30
                Layout.bottomMargin: 30
                text: root.chatDateTimeText
                font.pixelSize: Theme.additionalTextSize
                color: Theme.palette.baseColor1
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter

                StatusBaseText {
                    text: root.listUsersText
                    font.pixelSize: Theme.additionalTextSize
                }

                StatusBaseText {
                    text: qsTr("joined the channel")
                    font.pixelSize: Theme.additionalTextSize
                    color: Theme.palette.baseColor1
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: childrenRect.height + spacing
                Layout.topMargin: 16
                spacing: 16
                model: root.messagesModel
                delegate: StatusMessage {
                    width: ListView.view.width
                    timestamp: model.timestamp
                    enabled: false
                    messageDetails: StatusMessageDetails {
                        messageText: model.message
                        contentType: model.contentType
                        sender.displayName: model.senderDisplayName
                        sender.isContact: model.isContact
                        sender.trustIndicator: model.trustIndicator
                        sender.profileImage: StatusProfileImageSettings {
                            width: 40
                            height: 40
                            name: model.profileImage || ""
                            color: root.Theme.palette.userCustomizationColors[model.colorId]
                        }
                    }
                }
            }
        }
    }

    // Permissions base information content:
    Rectangle {
        id: panelBase

        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Theme.palette.statusAppLayout.rightPanelBackgroundColor
        gradient: Gradient {
            GradientStop {
                position: 0.000
                color: "transparent"
            }
            GradientStop {
                position: 0.180
                color: panelBase.color
            }
        }

        StatusScrollView {
            id: scrollView

            anchors.fill: parent
            padding: 0

            contentWidth: availableWidth

            Item {
                width: scrollView.availableWidth
                height: Math.max(overlayPanel.implicitHeight, panelBase.height)

                JoinPermissionsOverlayPanel {
                    id: overlayPanel

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    topPadding: 2 * bottomPadding
                    joinCommunity: root.joinCommunity
                    allChannelsAreHiddenBecauseNotPermitted: root.allChannelsAreHiddenBecauseNotPermitted
                    requirementsMet: root.requirementsMet
                    requirementsCheckPending: root.requirementsCheckPending
                    missingEncryptionKey: root.missingEncryptionKey
                    requestToJoinState: root.requestToJoinState
                    isJoinRequestRejected: root.isJoinRequestRejected
                    requiresRequest: root.requiresRequest
                    communityName: root.name
                    communityHoldingsModel: root.communityHoldingsModel
                    channelName: root.channelName

                    viewOnlyHoldingsModel: root.viewOnlyHoldingsModel
                    viewAndPostHoldingsModel: root.viewAndPostHoldingsModel
                    moderateHoldingsModel: root.moderateHoldingsModel
                    assetsModel: root.assetsModel
                    collectiblesModel: root.collectiblesModel

                    onRequestToJoinClicked: root.requestToJoinClicked()
                    onInvitationPendingClicked: root.invitationPendingClicked()
                }
            }
        }
    }

    Component {
        id: fastBlur

        FastBlur {
            radius: 32
            transparentBorder: true
        }
    }
}
