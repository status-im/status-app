import QtQuick
import QtQuick.Layouts

import StatusQ.Core.Theme
import StatusQ.Core.Backpressure
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups.Dialog

import utils
import shared.panels

import AppLayouts.Communities.panels
import AppLayouts.stores as AppLayoutStores
import AppLayouts.Profile.stores as ProfileStores

StatusAdaptiveStackDialog {
    id: root

    property var contactsModel
    property var community
    required property var membersModel

    property var pubKeys: ([])
    property string inviteMessage: ""
    property string validationError: ""
    property string successMessage: ""

    required property var shareCommunityToUsers

    QtObject {
        id: d

        function shareCommunity(pubKeys, inviteMessage) {
            const error = root.shareCommunityToUsers(JSON.stringify(pubKeys), inviteMessage);
            d.processInviteResult(error);
        }

        function processInviteResult(error) {
            if (error) {
                console.error('Error inviting', error);
                root.validationError = error;
            } else {
                root.validationError = "";
                root.successMessage = qsTr("Invite successfully sent");
                Backpressure.debounce(root, 500, () => {
                    root.close()
                })()
            }
        }
    }

    onOpened: {
        root.pubKeys = [];
        root.successMessage = "";
        root.validationError = "";
        root.resetStack();
    }

    defaultTitle: qsTr("Invite Contacts to %1").arg(community.name)
    subHeaderPadding: Theme.padding
    initialItem: inviteFriendsStepComponent

    subHeaderItem: Component {
        StyledText {
            text: root.validationError || root.successMessage
            visible: root.validationError !== "" || root.successMessage !== ""
            font.pixelSize: Theme.additionalTextSize
            color: !!root.validationError ? Theme.palette.dangerColor1 : Theme.palette.successColor1
            horizontalAlignment: Text.AlignHCenter
            height: visible ? contentHeight : 0
        }
    }

    Component {
        id: inviteFriendsStepComponent

        ProfilePopupInviteFriendsPanel {
            readonly property string nextButtonObjectName: "InviteFriendsToCommunityPopup_NextButton"
            readonly property string nextButtonText: qsTr("Next")
            readonly property bool canGoNext: root.pubKeys.length > 0
            readonly property var nextAction: () => root.stack.push(inviteMessageStepComponent)

            contactsModel: root.contactsModel
            membersModel: root.membersModel
            communityId: root.community.id

            onPubKeysChanged: root.pubKeys = pubKeys
        }
    }

    Component {
        id: inviteMessageStepComponent

        ProfilePopupInviteMessagePanel {
            readonly property string nextButtonObjectName: "InviteFriendsToCommunityPopup_SendButton"
            readonly property string nextButtonText: qsTr("Send %n invite(s)", "", root.pubKeys.length)
            readonly property bool canGoNext: root.pubKeys.length > 0
            readonly property var nextAction: () => d.shareCommunity(root.pubKeys, root.inviteMessage)

            contactsModel: root.contactsModel
            pubKeys: root.pubKeys
            onInviteMessageChanged: root.inviteMessage = inviteMessage
        }
    }
}
