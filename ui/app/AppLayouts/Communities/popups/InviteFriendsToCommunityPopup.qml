import QtQuick
import QtQuick.Layouts

import StatusQ.Core.Theme
import StatusQ.Core.Backpressure
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups

import utils
import shared.panels

import AppLayouts.Communities.panels
import AppLayouts.stores as AppLayoutStores
import AppLayouts.Profile.stores as ProfileStores

StatusStackModal {
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

        // values from Figma design
        readonly property int footerButtonsHeight: 44
        readonly property int popupContentHeight: 551

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
    }

    stackTitle: qsTr("Invite Contacts to %1").arg(community.name)
    width: 640
    height: d.popupContentHeight

    leftPadding: 0
    rightPadding: 0

    nextButton: StatusButton {
        objectName: "InviteFriendsToCommunityPopup_NextButton"
        implicitHeight: d.footerButtonsHeight
        text: qsTr("Next")
        enabled: root.pubKeys.length
        onClicked: {
            root.currentIndex++;
        }
    }

    finishButton: StatusButton {
        objectName: "InviteFriendsToCommunityPopup_SendButton"
        implicitHeight: d.footerButtonsHeight
        enabled: root.pubKeys.length > 0
        text: qsTr("Send %n invite(s)", "", root.pubKeys.length)
        onClicked: {
            d.shareCommunity(root.pubKeys, root.inviteMessage);
        }
    }

    subHeaderItem: StyledText {
        text: root.validationError || root.successMessage
        visible: root.validationError !== "" || root.successMessage !== ""
        font.pixelSize: Theme.additionalTextSize
        color: !!root.validationError ? Theme.palette.dangerColor1 : Theme.palette.successColor1
        horizontalAlignment: Text.AlignHCenter
        height: visible ? contentHeight : 0
    }

    stackItems: [
        ProfilePopupInviteFriendsPanel {

            contactsModel: root.contactsModel
            membersModel: root.membersModel
            communityId: root.community.id

            onPubKeysChanged: root.pubKeys = pubKeys
        },

        ProfilePopupInviteMessagePanel {
            contactsModel: root.contactsModel
            pubKeys: root.pubKeys
            onInviteMessageChanged: root.inviteMessage = inviteMessage
        }
    ]
}

