pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QtModelsToolkit

import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme

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
    property int messagesCount: 0

    /*!
       Unread/new activity count shown as a badge. Hidden when 0.
       Only used when threadState is ThreadCard.State.Active.
    */
    property int notificationCount: 0

    /*!
       Preview model of unique thread participants, with the thread creator first.
       Expected roles: id, name, image, and colorId.
       Only used when threadState is ThreadCard.State.Active.
    */
    property var participantsPreviewModel: null
    // Total count; participantsPreviewModel contains only the limited preview.
    property int participantsCount: 0

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

    readonly property int maximumWidth: 420
    readonly property real connectorY: contentItem.y + (d.deleted
        ? bodyRow.y + bodyRow.height / 2
        : titleRow.y + titleRow.height / 2)

    /*!
       Emitted when the user requests to open the thread.
    */
    signal clicked(string threadId, string originalMessageId)

    padding: Theme.padding
    implicitWidth: 296
    hoverEnabled: true

    QtObject {
        id: d

        readonly property bool deleted: root.threadState === ThreadCard.State.Deleted

        readonly property int avatarSize: 24
        readonly property int iconSize: 16
        readonly property int avatarSeparator: 2
        readonly property int avatarOuterSize: avatarSize + avatarSeparator * 2
        readonly property int avatarStep: avatarSize - Math.round(Theme.halfPadding / 2) + avatarSeparator
        readonly property int visibleParticipantsLimit: 6
        readonly property int availableParticipantsCount: root.participantsPreviewModel
                                                         ? root.participantsPreviewModel.ModelCount.count
                                                         : 0
        readonly property int visibleParticipantsCount: Math.min(availableParticipantsCount,
                                                                 visibleParticipantsLimit,
                                                                 Math.max(0, root.participantsCount))
        readonly property int remainingParticipantsCount: Math.max(0, root.participantsCount - visibleParticipantsCount)
        readonly property int avatarStackCount: visibleParticipantsCount + (remainingParticipantsCount > 0 ? 1 : 0)
        readonly property int avatarStackWidth: avatarStackCount > 0 ? avatarOuterSize + (avatarStackCount - 1) * avatarStep : 0
        readonly property var bodyMessage: deleted ? (root.deletedMessage || {}) : (root.lastMessage || {})
        readonly property var bodySender: bodyMessage.sender || {}
        readonly property string bodyMessageText: deleted ? qsTr("deleted this thread") : (bodyMessage.text || "")
        readonly property string bodyPreviewText: bodyMessageText.replace(/\s+/g, " ").trim()
        readonly property double bodyTimestamp: bodyMessage.timestamp || 0
        readonly property string formattedBodyTimestamp: bodyTimestamp > 0
                                                         ? LocaleUtils.formatRelativeTimestamp(bodyTimestamp)
                                                         : ""
        readonly property int bodyLineHeight: Theme.fontSize(18)
        readonly property int bodyTopMargin: Math.max(0, Math.round((avatarSize - bodyLineHeight) / 2))
        readonly property string messagesCountText: qsTr("%n message(s)", "", root.messagesCount)
    }

    HoverHandler { cursorShape: Qt.PointingHandCursor }

    TapHandler {
        onTapped: root.clicked(root.threadId, root.originalMessageId)
    }

    background: Rectangle {
        radius: Theme.radius
        color: root.hovered ? Theme.palette.baseColor2 : "transparent"
        border.width: 1
        border.color: Theme.palette.directColor7
    }

    contentItem: ColumnLayout {
        spacing: Theme.halfPadding

        // Active state title row.
        RowLayout {
            id: titleRow
            objectName: "threadCardTitleRow"
            Layout.fillWidth: true
            visible: !d.deleted
            spacing: 0

            Item {
                Layout.preferredWidth: d.avatarOuterSize
                Layout.preferredHeight: d.iconSize

                StatusIcon {
                    anchors.centerIn: parent
                    width: d.iconSize
                    height: d.iconSize
                    icon: "thread"
                    color: Theme.palette.primaryColor1
                }
            }

            StatusBaseText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: root.title
                elide: Text.ElideRight
                color: Theme.palette.directColor1
                font.pixelSize: Theme.primaryTextFontSize
                font.weight: Font.Bold
            }

            StatusBadge {
                objectName: "threadCardUnreadBadge"
                visible: root.notificationCount > 0
                value: root.notificationCount
                border.width: 0
            }
        }

        // Active state participants and message count row.
        RowLayout {
            Layout.fillWidth: true
            visible: !d.deleted && (d.avatarStackCount > 0 || root.messagesCount > 0)
            spacing: Theme.halfPadding

            Item {
                Layout.preferredWidth: d.avatarStackWidth
                Layout.minimumWidth: 0
                Layout.preferredHeight: d.avatarOuterSize
                visible: d.avatarStackCount > 0

                Repeater {
                    objectName: "threadCardParticipantsRepeater"
                    model: root.participantsPreviewModel

                    delegate: Item {
                        id: participantAvatar

                        required property int index
                        required property string name
                        required property string image
                        required property int colorId

                        x: index * d.avatarStep
                        width: d.avatarOuterSize
                        height: d.avatarOuterSize
                        objectName: "threadCardParticipantAvatar_" + index
                        visible: index < d.visibleParticipantsCount

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: root.hovered ? Theme.palette.baseColor2 : Theme.palette.baseColor4
                        }

                        StatusSmartIdenticon {
                            anchors.centerIn: parent
                            width: d.avatarSize
                            height: d.avatarSize
                            name: participantAvatar.name

                            asset {
                                width: d.avatarSize
                                height: d.avatarSize
                                color: Theme.palette.userCustomizationColors[participantAvatar.colorId]
                                name: participantAvatar.image
                                isImage: !!participantAvatar.image
                                isLetterIdenticon: !participantAvatar.image
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
                    color: root.hovered ? Theme.palette.baseColor2 : Theme.palette.baseColor4

                    Rectangle {
                        anchors.centerIn: parent
                        width: d.avatarSize
                        height: d.avatarSize
                        radius: width / 2
                        color: Theme.palette.primaryColor1

                        StatusBaseText {
                            objectName: "threadCardRemainingParticipants"
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
                objectName: "threadCardMessagesCount"
                visible: root.messagesCount > 0
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: d.messagesCountText
                elide: Text.ElideRight
                color: Theme.palette.primaryColor1
                font.pixelSize: Theme.primaryTextFontSize
                font.weight: Font.Bold
            }

        }

        // Body row for both states. Active renders the last message preview;
        // deleted renders the deletion summary.
        RowLayout {
            id: bodyRow
            objectName: "threadCardBodyRow"
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            visible: d.deleted || d.bodyMessageText.length > 0 || d.formattedBodyTimestamp.length > 0
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
                Layout.leftMargin: d.deleted ? 0 : d.avatarSeparator
                Layout.preferredWidth: d.avatarSize
                Layout.preferredHeight: d.avatarSize
                name: d.bodySender.name || ""

                asset {
                    width: d.avatarSize
                    height: d.avatarSize
                    color: d.bodySender.color
                           || Theme.palette.userCustomizationColors[d.bodySender.colorId || 0]
                    name: d.bodySender.image || ""
                    isImage: !!d.bodySender.image
                    isLetterIdenticon: !d.bodySender.image
                    charactersLen: 1
                }
            }

            Item {
                id: bodyContent

                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: Math.max(d.avatarSize,
                                         d.bodyTopMargin + (timestampSharesLine ? 1 : 2) * d.bodyLineHeight)

                readonly property bool timestampSharesLine: bodySenderLabel.width + Theme.halfPadding
                                                              + bodyMessageMetrics.advanceWidth
                                                              + bodyTimestampLabel.width + Theme.halfPadding <= width

                TextMetrics {
                    id: bodyMessageMetrics

                    text: d.bodyPreviewText
                    font: bodyLabel.font
                }

                StatusBaseText {
                    id: bodySenderLabel
                    objectName: "threadCardMessageSender"

                    y: d.bodyTopMargin
                    width: Math.min(implicitWidth, parent.width / 2)
                    height: d.bodyLineHeight
                    text: d.bodySender.name || ""
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.palette.directColor1
                    font.pixelSize: Theme.additionalTextSize
                    font.weight: Font.Bold
                    lineHeight: d.bodyLineHeight
                    lineHeightMode: Text.FixedHeight
                }

                StatusBaseText {
                    id: bodyLabel
                    objectName: "threadCardMessagePreview"

                    readonly property real firstLineX: bodySenderLabel.width + Theme.halfPadding
                    readonly property real firstLineWidth: Math.max(0, bodyContent.width - firstLineX
                        - (bodyContent.timestampSharesLine ? bodyTimestampLabel.width + Theme.halfPadding : 0))

                    onFirstLineXChanged: forceLayout()
                    onFirstLineWidthChanged: forceLayout()

                    y: d.bodyTopMargin
                    // The final line always leaves room for the timestamp.
                    width: Math.max(0, parent.width - bodyTimestampLabel.width - Theme.halfPadding)
                    text: d.bodyPreviewText
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: Theme.palette.directColor5
                    font.pixelSize: Theme.additionalTextSize
                    lineHeight: d.bodyLineHeight
                    lineHeightMode: Text.FixedHeight

                    onLineLaidOut: line => {
                        if (line.number !== 0)
                            return
                        line.x = firstLineX
                        line.width = firstLineWidth
                    }
                }

                StatusBaseText {
                    id: bodyTimestampLabel

                    anchors.right: parent.right
                    objectName: "threadCardTimestamp"

                    y: d.bodyTopMargin + (bodyContent.timestampSharesLine ? 0 : d.bodyLineHeight)
                    width: implicitWidth
                    height: d.bodyLineHeight
                    text: d.formattedBodyTimestamp
                    color: Theme.palette.directColor5
                    horizontalAlignment: Text.AlignRight
                    lineHeight: d.bodyLineHeight
                    lineHeightMode: Text.FixedHeight
                    font.pixelSize: Theme.additionalTextSize
                    font.weight: Font.Normal
                }
            }
        }
    }
}
