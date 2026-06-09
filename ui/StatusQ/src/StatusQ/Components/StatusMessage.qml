import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Controls

import QtModelsToolkit

import "./private/statusMessage"

Control {
    id: root

    enum ContentType {
        Unknown = 0,
        Text = 1,
        Emoji = 2,
        Image = 3,
        Sticker = 4,
        Audio = 5, // Not used
        Transaction = 6,
        Invitation = 7,
        DiscordMessage = 8,
        SystemMessagePinnedMessage = 14,
        SystemMessageMutualEventSent = 15,
        SystemMessageMutualEventAccepted = 16,
        SystemMessageMutualEventRemoved = 17,
        BridgeMessage = 18
    }

    enum OutgoingStatus {
        Unknown = 0,
        Sending,
        Sent,
        Delivered,
        Expired,
        FailedResending
    }

    property list<Item> quickActions
    property var statusChatInput
    property alias linksComponent: linksLoader.sourceComponent
    property alias invitationComponent: invitationBubbleLoader.sourceComponent

    property string pinnedMsgInfoText: ""

    property string messageAttachments: ""
    property var linkPreviewModel
    property var paymentRequestModel
    property var gifLinks

    property string messageId: ""
    property bool editMode: false
    property bool isAReply: false
    property bool isEdited: false

    property bool hasMention: false
    property bool isPinned: false
    property string pinnedBy: ""
    property string resendError: ""
    property int outgoingStatus: StatusMessage.OutgoingStatus.Unknown
    property double timestamp: 0
    property var reactionsModel
    property int maxEmojiReactionsPerMessage

    property bool showHeader: true
    property bool isActiveMessage: false
    property bool disableHover: false
    property bool disableEmojis: false
    property color overrideBackgroundColor: "transparent"
    property bool overrideBackground: false
    property bool profileClickable: true
    property bool hideMessage: false
    property bool isInPinnedPopup
    property string highlightedLink: ""
    property string hoveredLink: ""
    property bool linkAddressAndEnsName
    property string disabledTooltipText

    property bool isMobile: Utils.isMobile

    property StatusMessageDetails messageDetails: StatusMessageDetails {}
    property StatusMessageDetails replyDetails: StatusMessageDetails {}

    signal profilePictureClicked(var sender, var mouse)
    signal senderNameClicked(var sender)
    signal replyProfileClicked(var sender, var mouse)
    signal replyMessageClicked(var mouse)
    signal contextMenuRequested(point pos)

    signal addReactionClicked(var sender, var mouse)
    signal toggleReactionClicked(string hexcode)
    signal imageClicked(var image, var mouse, var imageSource, point pos)
    signal stickerClicked()
    signal resendClicked()

    signal editCompleted(string newMsgText)
    signal editCancelled()
    signal stickerLoaded()
    signal linkActivated(string link)

    signal hoverChanged(string messageId, bool hovered)

    function startMessageFoundAnimation() {
        messageFoundAnimation.restart();
    }

    onMessageAttachmentsChanged: {
        root.prepareAttachmentsModel()
    }

    function prepareAttachmentsModel() {
        attachmentsModel.clear()
        if (!root.messageAttachments) {
            return
        }
        root.messageAttachments.split(" ").forEach(source => {
            attachmentsModel.append({source})
        })
    }

    hoverEnabled: (!root.isActiveMessage && !root.disableHover)
    opacity: outgoingStatus === StatusMessage.OutgoingStatus.Sending ? 0.5 : 1.0
    background: Rectangle {
        color: {
            if (root.overrideBackground)
                return root.overrideBackgroundColor;

            if (root.editMode)
                return Theme.palette.baseColor2;

            if (root.hovered || root.isActiveMessage) {
                if (root.hasMention)
                    return Theme.palette.mentionColor3;
                if (root.isPinned)
                    return Theme.palette.pinColor2;
                return Theme.palette.baseColor2;
            }

            if (root.hasMention)
                return Theme.palette.mentionColor4;
            if (root.isPinned)
                return Theme.palette.pinColor3;
            return "transparent";
        }

        SequentialAnimation {
            id: messageFoundAnimation

            NumberAnimation {
                target: highlightRect
                property: "opacity"
                to: 1.0
                duration: 250
            }
            PauseAnimation {
                duration: 1000
            }
            NumberAnimation {
                target: highlightRect
                property: "opacity"
                to: 0.0
                duration: 1500
            }
        }

        Rectangle {
            id: highlightRect
            anchors.fill: parent
            opacity: 0
            visible: opacity > 0.001
            color: Theme.palette.messageHighlightColor
        }

        Rectangle {
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
            width: 2
            visible: root.isPinned || root.hasMention
            color: root.hasMention ? Theme.palette.mentionColor1 : root.isPinned ? Theme.palette.pinColor1
                                                                                 : "transparent" // not visible really
        }
    }

    contentItem: Item {

        implicitWidth: messageLayout.implicitWidth
        implicitHeight: messageLayout.implicitHeight

        ColumnLayout {
            id: messageLayout
            anchors.fill: parent
            spacing: 2

            Loader {
                Layout.fillWidth: true
                active: isAReply &&
                    root.messageDetails.contentType !== StatusMessage.ContentType.SystemMessagePinnedMessage &&
                    root.messageDetails.contentType !== StatusMessage.ContentType.SystemMessageMutualEventSent &&
                    root.messageDetails.contentType !== StatusMessage.ContentType.SystemMessageMutualEventAccepted &&
                    root.messageDetails.contentType !== StatusMessage.ContentType.SystemMessageMutualEventRemoved

                visible: active
                sourceComponent: StatusMessageReply {
                    objectName: "StatusMessage_replyDetails"
                    isMobile: root.isMobile
                    replyDetails: root.replyDetails
                    profileClickable: root.profileClickable
                    onReplyProfileClicked: (sender, mouse) => root.replyProfileClicked(sender, mouse)
                    onMessageClicked: mouse => root.replyMessageClicked(mouse)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding
                Layout.rightMargin: Theme.padding
                spacing: Theme.halfPadding

                StatusUserImage {
                    id: profileImage
                    Layout.alignment: Qt.AlignTop
                    active: root.showHeader
                    visible: active
                    name: root.messageDetails.sender.displayName
                    usesDefaultName: root.messageDetails.sender.usesDefaultName
                    userColor: root.messageDetails.sender.profileImage.assetSettings.color
                    image: root.messageDetails.sender.profileImage.assetSettings.name
                    interactive: true
                    imageWidth: root.messageDetails.sender.profileImage.assetSettings.width
                    imageHeight: root.messageDetails.sender.profileImage.assetSettings.height
                    isBridgedAccount: root.messageDetails.contentType === StatusMessage.ContentType.BridgeMessage
                    onClicked: (mouse) => root.profilePictureClicked(this, mouse)
                }

                ColumnLayout {
                    spacing: 2
                    Layout.alignment: Qt.AlignTop
                    Layout.fillWidth: true
                    Layout.leftMargin: profileImage.active ? 0 : root.messageDetails.sender.profileImage.assetSettings.width + parent.spacing

                    StatusPinMessageDetails {
                        active: root.isPinned && !editMode
                        visible: active
                        pinnedMsgInfoText: root.pinnedMsgInfoText
                        pinnedBy: root.pinnedBy
                    }
                    Loader {
                        Layout.fillWidth: true
                        active: root.showHeader && !editMode
                        visible: active
                        sourceComponent: StatusMessageHeader {
                            sender: root.messageDetails.sender
                            amISender: root.messageDetails.amISender
                            messageOriginInfo: root.messageDetails.messageOriginInfo
                            resendError: root.messageDetails.amISender ? root.resendError : ""
                            onClicked: (sender) => root.senderNameClicked(sender)
                            onResendClicked: root.resendClicked()
                            timestamp: root.timestamp
                            displayNameClickable: root.profileClickable
                            outgoingStatus: root.outgoingStatus
                            showOutgointStatusLabel: root.hovered && !root.isInPinnedPopup
                        }
                    }
                    Loader {
                        Layout.fillWidth: true
                        active: (!root.editMode && !!root.messageDetails.messageText && !root.hideMessage
                                 && ((root.messageDetails.contentType === StatusMessage.ContentType.Text) ||
                                     (root.messageDetails.contentType === StatusMessage.ContentType.Emoji) ||
                                     (root.messageDetails.contentType === StatusMessage.ContentType.DiscordMessage) ||
                                     (root.messageDetails.contentType === StatusMessage.ContentType.Invitation) ||
                                     (root.messageDetails.contentType === StatusMessage.ContentType.BridgeMessage)))
                        visible: active
                        sourceComponent: StatusTextMessageCommon {}
                    }
                    Loader {
                        active: root.messageDetails.contentType === StatusMessage.ContentType.Image && !editMode
                        visible: active
                        Layout.fillWidth: true

                        sourceComponent: Column {
                            id: imagesColumn
                            spacing: Theme.halfPadding
                            Loader {
                                active: root.messageDetails.messageText !== ""
                                anchors.left: parent.left
                                anchors.right: parent.right
                                visible: active
                                sourceComponent: StatusTextMessageCommon {}
                            }

                            Loader {
                                active: true
                                sourceComponent: StatusMessageImageAlbum {
                                    objectName: "StatusMessage_imageAlbum"
                                    readonly property int effectiveAlbumCount: Math.max(1, root.messageDetails.albumCount)

                                    width: messageLayout.width
                                    album: root.messageDetails.albumCount > 0 ? root.messageDetails.album : [root.messageDetails.messageContent]
                                    albumCount: effectiveAlbumCount
                                    imageWidth: Math.max(1, Math.min((messageLayout.width - 9 * (effectiveAlbumCount - 1)) / effectiveAlbumCount, 144))
                                    shapeType: StatusImageMessage.ShapeType.LEFT_ROUNDED
                                    onImageClicked: (image, mouse, imageSource, pos) => root.imageClicked(image, mouse, imageSource, pos)
                                }
                            }
                        }
                    }

                    Loader {
                        active: root.messageAttachments && !editMode
                        visible: active
                        sourceComponent: Column {
                            spacing: 4
                            Layout.fillWidth: true
                            Repeater {
                                model: attachmentsModel
                                delegate: StatusImageMessage {
                                    source: model.source
                                    onClicked: (image, mouse, imageSource, pos) => root.imageClicked(image, mouse, imageSource, pos)
                                    shapeType: StatusImageMessage.ShapeType.LEFT_ROUNDED
                                }
                            }
                        }
                    }
                    StatusSticker {
                        active: root.messageDetails.contentType === StatusMessage.ContentType.Sticker && !editMode
                        visible: active
                        asset.isImage: true
                        asset.name: root.messageDetails.messageContent
                        onStickerLoaded: root.stickerLoaded()
                        onClicked: root.stickerClicked()
                    }
                    Loader {
                        id: linksLoader
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        active: parent.visible && !root.editMode &&
                                ((!!root.linkPreviewModel && root.linkPreviewModel.count > 0)
                                || (!!root.gifLinks && root.gifLinks.length > 0)
                                || (!!root.paymentRequestModel && root.paymentRequestModel.ModelCount.count > 0))
                        visible: active 
                    }
                    Loader {
                        id: invitationBubbleLoader
                        // TODO remove this component in #12570
                        active: root.messageDetails.contentType === StatusMessage.ContentType.Invitation && !editMode
                        visible: active
                    }

                    Loader {
                        Layout.fillWidth: true
                        Layout.rightMargin: Theme.padding
                        active: root.editMode
                        visible: active
                        sourceComponent: StatusEditMessage {
                            inputComponent: root.statusChatInput
                            messageText: root.messageDetails.messageText
                            onEditCancelled: root.editCancelled()
                            onEditCompleted: (newMsgText) => root.editCompleted(newMsgText)
                        }
                    }
                    Loader {
                        active: !!root.reactionsModel && root.reactionsModel.ModelCount.count > 0
                        visible: active
                        Layout.fillWidth: true
                        sourceComponent: StatusMessageEmojiReactions {
                            id: emojiReactionsPanel
                            enabled: !root.disableEmojis
                            reactionsModel: root.reactionsModel
                            limitReached: !!root.reactionsModel && root.reactionsModel.ModelCount.count >= root.maxEmojiReactionsPerMessage
                            messageHighlighted: root.hovered || root.isActiveMessage

                            onHoverChanged: (hovered) => root.hoverChanged(messageId, hovered)

                            onAddEmojiClicked: (sender, mouse) => root.addReactionClicked(sender, mouse)
                            onToggleReaction: (hexcode) => root.toggleReactionClicked(hexcode)
                        }
                    }
                }
            }
        }

        Loader {
            active: root.hovered && root.quickActions.length > 0
                    && !Utils.isMobile // hover menu disabled on mobile; we use the MessageContextMenuView
            visible: active
            anchors.right: parent.right
            anchors.rightMargin: Theme.padding
            anchors.verticalCenter: parent.top
            sourceComponent: StatusMessageQuickActions {
                items: root.quickActions
            }
        }
    }

    ListModel {
        id: attachmentsModel
        Component.onCompleted: {
            root.prepareAttachmentsModel()
        }
    }

    component StatusTextMessageCommon: StatusTextMessage {
        objectName: "StatusMessage_textMessage"
        messageDetails: root.messageDetails
        isEdited: root.isEdited
        allowShowMore: !root.isInPinnedPopup
        textField.anchors.rightMargin: root.isInPinnedPopup ? Theme.xlPadding : 0 // margin for the "Unpin" floating button
        highlightedLink: root.highlightedLink
        linkAddressAndEnsName: root.linkAddressAndEnsName
        disabledTooltipText: root.disabledTooltipText
        isMobile: root.isMobile
        onLinkActivated: link => root.linkActivated(link)
        onHoveredLinkChanged: root.hoveredLink = hoveredLink
        onContextMenuRequested: pos => root.contextMenuRequested(pos)
    }
}
