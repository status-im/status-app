import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import shared.status
import utils

ColumnLayout {
    id: root
    spacing: 0

    // The owner supplies the parent content and async state; this panel edits the draft.
    required property Component parentMessageContent
    required property string parentMessageText
    property var usersModel
    property string initialText
    property string initialThreadName
    property bool initialStartNewThread: true
    property var initialMentionsMap: ({})
    property bool canPost: true
    property bool pending: false
    property string error
    readonly property alias chatInput: input
    readonly property bool readyForFocus: visible && !!Window.window
    onReadyForFocusChanged: if (readyForFocus) Qt.callLater(input.forceInputActiveFocus)

    signal sendRequested(string text, string threadName, bool startNewThread)

    Component.onCompleted: {
        if (root.initialText)
            input.textInput.loadText(root.initialText, root.initialMentionsMap)
    }

    ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: availableWidth

        Loader {
            width: parent.width
            sourceComponent: root.parentMessageContent
        }
    }

    StatusBaseText {
        objectName: "newThreadError"
        Layout.fillWidth: true
        Layout.margins: Theme.padding
        visible: !!root.error
        text: root.error
        textFormat: Text.PlainText
        color: Theme.palette.dangerColor1
        wrapMode: Text.Wrap
    }

    StatusChatInput {
        id: input
        Layout.fillWidth: true
        Layout.margins: Theme.halfPadding
        threadsEnabled: true
        startNewThread: root.initialStartNewThread
        preserveInputOnSend: true
        initialThreadName: root.initialThreadName
        newThreadNamePlaceholder: SQUtils.StringUtils.plainTextSingleLine(
                                      SQUtils.StringUtils.escapeHtml(root.parentMessageText),
                                      Constants.maxThreadNameLength)
        usersModel: root.usersModel
        // The existing-message creation API accepts a text reply.
        imageFeaturesEnabled: false
        stickersButtonVisible: false
        gifButtonVisible: false
        sendEnabled: root.canPost && !root.pending
        textInput.readOnly: root.pending

        Component.onCompleted: Qt.callLater(forceInputActiveFocus)

        onSendMessageRequested: (startNewThread, newThreadName, alsoReplyToParentChat) => {
            const text = input.getTextWithPublicKeys()
            if (!root.pending && root.canPost && text.trim())
                root.sendRequested(text, newThreadName, startNewThread)
        }
    }
}
