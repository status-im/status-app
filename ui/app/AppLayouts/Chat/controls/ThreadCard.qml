pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

/*!
   Compact summary of a chat thread in active or deleted state.
*/
Control {
    id: root

    enum State {
        Active,
        Deleted
    }

    /*!
       Stable identifier of the thread opened when the card is clicked.
    */
    property string threadId: ""

    /*!
       Identifier of the channel message that started the thread.
    */
    property string originalMessageId: ""

    /*!
       Visual state of the thread card.
    */
    property int threadState: ThreadCard.State.Active

    /*!
       Thread title shown in the active state.
       Only used when threadState is ThreadCard.State.Active.
    */
    property string title: ""

    /*!
       Total number of messages in the thread, including the message that started it.
       Only used when threadState is ThreadCard.State.Active.
    */
    property int messageCount: 0

    /*!
       Unread/new activity count shown as a badge. Hidden when 0.
       Only used when threadState is ThreadCard.State.Active.
    */
    property int notificationCount: 0

    /*!
       Unique thread participants ordered with the thread creator first, followed by recent participants.
       Each item may expose id, name, image, and color.
       Only used when threadState is ThreadCard.State.Active.
    */
    property var participants: []

    /*!
       Last thread message preview data. Accepts a JS object or QtObject with:
       sender: { name, image, color }, text, and timestamp.
       Only used when threadState is ThreadCard.State.Active.
    */
    property var lastMessage: ({})

    /*!
       Deleted thread message data. Accepts a JS object or QtObject with:
       sender: { name, image, color } and timestamp.
       Only used when threadState is ThreadCard.State.Deleted.
    */
    property var deletedMessage: ({})

    /*!
       Emitted when the user requests to open the thread.
    */
    signal clicked(string threadId, string originalMessageId)

    padding: Theme.padding
    implicitWidth: 296

    QtObject {
        id: d

        readonly property bool deleted: root.threadState === ThreadCard.State.Deleted

        readonly property int avatarSize: 24
        readonly property int iconSize: 16
        readonly property int avatarSeparator: 2
        readonly property int avatarOuterSize: avatarSize + avatarSeparator * 2
        readonly property int avatarStep: avatarSize - Math.round(Theme.halfPadding / 2) + avatarSeparator
        readonly property int visibleParticipantsLimit: 6
        readonly property int visibleParticipantsCount: Math.min(root.participants.length, visibleParticipantsLimit)
        readonly property int remainingParticipantsCount: root.participants.length - visibleParticipantsCount
        readonly property int avatarStackCount: visibleParticipantsCount + (remainingParticipantsCount > 0 ? 1 : 0)
        readonly property int avatarStackWidth: avatarStackCount > 0 ? avatarOuterSize + (avatarStackCount - 1) * avatarStep : 0
        readonly property var bodyMessage: deleted ? (root.deletedMessage || {}) : (root.lastMessage || {})
        readonly property var bodySender: bodyMessage.sender || {}
        readonly property string bodyMessageText: deleted ? qsTr("deleted this thread") : (bodyMessage.text || "")
        readonly property int bodyMessageCharacterLimit: 50
        readonly property string bodyPreviewText: bodyMessageText.length > bodyMessageCharacterLimit
                                                  ? bodyMessageText.slice(0, bodyMessageCharacterLimit - 1) + "…"
                                                  : bodyMessageText
        readonly property double bodyTimestamp: bodyMessage.timestamp || 0
        readonly property string formattedBodyTimestamp: bodyTimestamp > 0
                                                         ? LocaleUtils.formatRelativeTimestamp(bodyTimestamp)
                                                         : ""
        readonly property int bodyLineHeight: Theme.fontSize(18)
        readonly property int bodyTopMargin: Math.max(0, Math.round((avatarSize - bodyLineHeight) / 2))
        readonly property string messageCountText: qsTr("%n message(s)", "", root.messageCount)
    }

    HoverHandler {
        id: hoverHandler

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.clicked(root.threadId, root.originalMessageId)
    }

    background: Rectangle {
        radius: Theme.smallPadding
        color: hoverHandler.hovered ? Theme.palette.baseColor3 : Theme.palette.baseColor4
        border.width: 1
        border.color: Theme.palette.directColor7
    }

    contentItem: ColumnLayout {
        spacing: Theme.halfPadding

        // Active state title row.
        RowLayout {
            Layout.fillWidth: true
            visible: !d.deleted
            spacing: Theme.halfPadding

            StatusIcon {
                Layout.preferredWidth: d.iconSize
                Layout.preferredHeight: d.iconSize
                icon: "thread"
                color: Theme.palette.primaryColor1
            }

            StatusBaseText {
                Layout.fillWidth: true
                text: root.title
                elide: Text.ElideRight
                color: Theme.palette.directColor1
                font.pixelSize: Theme.primaryTextFontSize
                font.weight: Font.Bold
            }

            StatusBadge {
                visible: root.notificationCount > 0
                value: root.notificationCount
                border.width: 0
            }
        }

        // Active state participants and message count row.
        RowLayout {
            Layout.fillWidth: true
            visible: !d.deleted
            spacing: Theme.halfPadding

            Item {
                Layout.preferredWidth: d.avatarStackWidth
                Layout.preferredHeight: d.avatarOuterSize
                visible: d.avatarStackCount > 0

                Repeater {
                    model: d.visibleParticipantsCount

                    delegate: Item {
                        id: participantAvatar

                        required property int index

                        readonly property var participant: root.participants[index] || {}

                        x: index * d.avatarStep
                        width: d.avatarOuterSize
                        height: d.avatarOuterSize

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: hoverHandler.hovered ? Theme.palette.baseColor3 : Theme.palette.baseColor4
                        }

                        StatusSmartIdenticon {
                            anchors.centerIn: parent
                            width: d.avatarSize
                            height: d.avatarSize
                            name: participantAvatar.participant.name || ""

                            asset {
                                width: d.avatarSize
                                height: d.avatarSize
                                color: participantAvatar.participant.color || Theme.palette.miscColor5
                                name: participantAvatar.participant.image || ""
                                isImage: !!participantAvatar.participant.image
                                isLetterIdenticon: !participantAvatar.participant.image
                                charactersLen: 1
                            }
                        }
                    }
                }

                Rectangle {
                    x: d.visibleParticipantsCount * d.avatarStep
                    width: d.avatarOuterSize
                    height: d.avatarOuterSize
                    visible: d.remainingParticipantsCount > 0
                    radius: width / 2
                    color: hoverHandler.hovered ? Theme.palette.baseColor3 : Theme.palette.baseColor4

                    Rectangle {
                        anchors.centerIn: parent
                        width: d.avatarSize
                        height: d.avatarSize
                        radius: width / 2
                        color: Theme.palette.primaryColor1

                        StatusBaseText {
                            anchors.centerIn: parent
                            text: "+" + d.remainingParticipantsCount
                            color: Theme.palette.statusBadge.foregroundColor
                            font.pixelSize: Theme.additionalTextSize
                            font.weight: Font.Bold
                        }
                    }
                }
            }

            StatusBaseText {
                text: d.messageCountText
                color: Theme.palette.primaryColor1
                font.pixelSize: Theme.primaryTextFontSize
                font.weight: Font.Bold
            }

            Item {
                Layout.fillWidth: true
            }
        }

        // Body row for both states. Active renders the last message preview;
        // deleted renders the deletion summary.
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: d.deleted ? Math.round(Theme.halfPadding / 2) : Theme.halfPadding

            Rectangle {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: d.avatarSize
                Layout.preferredHeight: d.avatarSize
                visible: d.deleted
                radius: width / 2
                color: Theme.palette.dangerColor3

                StatusIcon {
                    anchors.centerIn: parent
                    width: d.iconSize
                    height: d.iconSize
                    icon: "delete"
                    color: Theme.palette.dangerColor1
                }
            }

            StatusSmartIdenticon {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: d.avatarSize
                Layout.preferredHeight: d.avatarSize
                name: d.bodySender.name || ""

                asset {
                    width: d.avatarSize
                    height: d.avatarSize
                    color: d.bodySender.color || Theme.palette.miscColor5
                    name: d.bodySender.image || ""
                    isImage: !!d.bodySender.image
                    isLetterIdenticon: !d.bodySender.image
                    charactersLen: 1
                }
            }

            Item {
                id: bodyContent

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: Math.max(d.avatarSize,
                                         d.bodyTopMargin + (timestampSharesLine
                                                            ? bodyLabel.implicitHeight
                                                            : Math.max(bodyLabel.implicitHeight,
                                                                       2 * d.bodyLineHeight)))

                readonly property bool timestampSharesLine: bodyNameMetrics.advanceWidth
                                                              + bodyMessageMetrics.advanceWidth
                                                              + Theme.halfPadding
                                                              + bodyTimestampLabel.width <= width

                TextMetrics {
                    id: bodyNameMetrics

                    text: d.bodySender.name || ""
                    font.family: bodyLabel.font.family
                    font.pixelSize: bodyLabel.font.pixelSize
                    font.weight: Font.Bold
                }

                TextMetrics {
                    id: bodyMessageMetrics

                    text: " " + d.bodyPreviewText
                    font.family: bodyLabel.font.family
                    font.pixelSize: bodyLabel.font.pixelSize
                    font.weight: Font.Normal
                }

                StatusBaseText {
                    id: bodyLabel

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: d.bodyTopMargin
                    text: `<b><font color="${Theme.palette.directColor1}">` +
                          `${SQUtils.StringUtils.escapeHtml(d.bodySender.name || "")}</font></b> ` +
                          `<font color="${Theme.palette.directColor5}">` +
                          `${SQUtils.StringUtils.escapeHtml(d.bodyPreviewText)}</font>`
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    lineHeight: d.bodyLineHeight
                    lineHeightMode: Text.FixedHeight
                    font.pixelSize: Theme.additionalTextSize
                    font.weight: Font.Normal

                    // Reserve timestamp space only on the line where it is rendered.
                    onLineLaidOut: line => {
                        const timestampLine = bodyContent.timestampSharesLine ? 0 : 1
                        if (line.number === timestampLine)
                            line.width = Math.max(0, width - bodyTimestampLabel.width - Theme.halfPadding)
                    }
                }

                StatusBaseText {
                    id: bodyTimestampLabel

                    anchors.right: parent.right
                    y: bodyContent.timestampSharesLine ? d.bodyTopMargin : parent.height - height
                    width: Math.min(implicitWidth, parent.width / 2)
                    height: d.bodyLineHeight
                    text: d.formattedBodyTimestamp
                    color: Theme.palette.directColor5
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Theme.additionalTextSize
                    font.weight: Font.Normal
                }
            }
        }
    }
}
