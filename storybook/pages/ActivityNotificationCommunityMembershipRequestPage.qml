import QtCore
import QtQuick

import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import AppLayouts.ActivityCenter.views
import AppLayouts.ActivityCenter.helpers

import AppLayouts.Chat.stores as ChatStores

import utils

import Storybook

SplitView {
    id: root

    readonly property int leftPanelMaxWidth: 308 // It fits on mobile / portrait + desktop left panel
    property bool utilsReady: false


    QtObject {
        id: contactDetailsMock

        readonly property string localNickname: editor.notificationBaseMock.title
        readonly property string name: contactName.text
        readonly property string alias: contactAlias.text
        readonly property string compressedPubKey: "zQ3...Ww4PG2"
        readonly property bool isContact: contactVerified.checked
    }

    QtObject {
        id: utilsMock

        function isCompressedPubKey(key) {
            return true
        }

        function getColorId(publicKey) {
            return 1
        }

        function isEnsVerified(publicKey) {
            return true
        }

        Component.onCompleted: {
            Utils.mainModuleInst = this
            Utils.globalUtilsInst = this
            root.utilsReady = true
        }
        Component.onDestruction: {
            root.utilsReady = false
            Utils.mainModuleInst = {}
            Utils.globalUtilsInst = {}
        }
    }

    ChatStores.RootStore {
        id: storeMock

        property var contactsStore: QtObject {
            property var myContactsModel: QtObject {
                signal itemChanged(string pubKey)
            }
        }
    }

    QtObject {
        id: notificationMock
        property string id: editor.notificationBaseMock.id
        property string chatId: "1"
        property string communityId: "1"
        property int membershipStatus: stateSelector.currentValue
        property int verificationStatus: 1
        property string sectionId: "1"
        property string name: editor.notificationBaseMock.title
        property string author: "author"
        property int notificationType: 1
        property var message: QtObject {
            property bool amISender: false
        }

        property int timestamp: editor.notificationBaseMock.timestamp
        property int previousTimestamp: editor.notificationBaseMock.previousTimestamp
        property bool read: editor.notificationBaseMock.read
        property bool dismissed: editor.notificationBaseMock.dismissed
        property bool accepted: editor.notificationBaseMock.accepted
        property var repliedMessage: ({})
        property int chatType: 1
    }

    Settings {
        property alias activityNotificationRequestState: stateSelector.currentIndex
    }

    function acceptRequestToJoinCommunity(notificationId, communityId) {
        stateSelector.currentIndex = stateSelector.indexOfValue(ActivityCenterTypes.ActivityCenterMembershipStatus.AcceptedPending)
    }

    function declineRequestToJoinCommunity(notificationId, communityId) {
        stateSelector.currentIndex = stateSelector.indexOfValue(ActivityCenterTypes.ActivityCenterMembershipStatus.DeclinedPending)
    }

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        Logs { id: logs }

        Item {
            id: wrapper
            SplitView.fillHeight: true
            SplitView.fillWidth: true

            Loader {
                active: root.utilsReady
                anchors.centerIn: parent
                width: root.leftPanelMaxWidth

                sourceComponent : ActivityNotificationCommunityMembershipRequest {
                    notification: notificationMock
                    contactsModel: ListModel {}
                    contactDetails: contactDetailsMock
                    community: communityEditor.communityMock

                    onSetActiveCommunityRequested: (communityId) => {
                                                       logs.logEvent("ActivityNotificationCommunityMembershipRequest::onSetActiveCommunityRequested: " + communityId) }
                    onAcceptRequestToJoinCommunityRequested: (requestId, communityId) => {
                                                                 logs.logEvent("ActivityNotificationCommunityMembershipRequest::onAcceptRequestToJoinCommunityRequested" ,
                                                                               ["requestId", "communityId"],
                                                                               [requestId, communityId])

                                                                 root.acceptRequestToJoinCommunity(requestId, communityId)
                                                             }
                    onDeclineRequestToJoinCommunityRequested: (requestId, communityId) => {
                                                                  logs.logEvent("ActivityNotificationCommunityMembershipRequest::onDeclineRequestToJoinCommunityRequested" ,
                                                                                ["requestId", "communityId"],
                                                                                [requestId, communityId])
                                                                  root.declineRequestToJoinCommunity(requestId, communityId)
                                                              }
                    onOpenProfilePopup: (contactId) =>
                                        logs.logEvent("ActivityNotificationCommunityMembershipRequest::onOpenProfilePopup" + contactId)
                }
            }
        }

        LogsAndControlsPanel {
            SplitView.minimumHeight: 100
            SplitView.preferredHeight: 160

            logsView.logText: logs.logText
        }
    }

    Pane {
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 300

        ActivityNotificationBaseEditor {
            id: editor

            ActivityNotificationCommunityEditor {
                id: communityEditor
            }

            // Contact related properties:
            Label {
                Layout.fillWidth: true
                Layout.topMargin: 8
                text: "Contact Name:"
                font.weight: Font.Bold
            }

            TextField {
                id: contactName
                Layout.fillWidth: true
                text: "Anna"
            }

            Label {
                Layout.fillWidth: true
                Layout.topMargin: 8
                text: "Alias:"
                font.weight: Font.Bold
            }

            TextField {
                id: contactAlias
                Layout.fillWidth: true
                text: "ui-dev"
            }

            Switch {
                id: contactVerified

                text: "Contact verified?"
                checked: true
            }

            Label {
                text: "Request state"
                font.weight: Font.Bold
            }

            ComboBox {
                id: stateSelector
                textRole: "text"
                valueRole: "value"
                model: ListModel {
                    id: model

                    ListElement { text: "Pending"; value: ActivityCenterTypes.ActivityCenterMembershipStatus.Pending }
                    ListElement { text: "Accepted"; value: ActivityCenterTypes.ActivityCenterMembershipStatus.Accepted }
                    ListElement { text: "Declined"; value: ActivityCenterTypes.ActivityCenterMembershipStatus.Declined }
                    ListElement { text: "AcceptedPending"; value: ActivityCenterTypes.ActivityCenterMembershipStatus.AcceptedPending }
                    ListElement { text: "DeclinedPending"; value: ActivityCenterTypes.ActivityCenterMembershipStatus.DeclinedPending }
                }
            }
        }
    }
}

// category: Activity Center
// status: good
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba⎜Desktop?type=design&node-id=35909-606817&mode=design&t=Ia7Z0AzyYIjkuPtr-0
