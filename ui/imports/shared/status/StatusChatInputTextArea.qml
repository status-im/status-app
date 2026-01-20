import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils

import shared
import shared.controls.chat
import shared.panels

import mainui

import AppLayouts.Chat.panels

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups
import StatusQ.Popups.Dialog
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Components
import StatusQ.Controls as StatusQ

import QtModelsToolkit

StatusQ.StatusTextArea {
    id: messageInputField

    property int messageLimit: 20
    property int messageLimitHard: 200

    property var urlsList: []

    property int previousCursorPosition: 0
    property KeyEvent lastKeyPressedEvent

    textFormat: Text.RichText

    color: Theme.palette.textColor
    topPadding: 9
    bottomPadding: 9
    leftPadding: 0
    rightPadding: 0
    background: null

    inputMethodHints: Qt.ImhMultiLine | Qt.ImhNoEditMenu
    EnterKey.type: Qt.EnterKeyReturn // insert newlines hint for OSK

    Keys.onShortcutOverride: function (event) {
        event.accepted = event.matches(StandardKey.Paste)
    }
    Keys.onUpPressed: function(event) {
        if (isEdit && !activeFocus) {
            forceActiveFocus();
        } else {
            if (messageInputField.length === 0) {
                root.keyUpPress();
            }
        }
        event.accepted = false
    }
    Keys.onPressed: function(event) {
        lastKeyPressedEvent = event
        onKeyPress(event)
    }
    Keys.onReleased: (event) => onRelease(event) // gives much more up to date cursorPosition

    onCursorPositionChanged: {
        if(mentionsPos.length > 0 && ((lastKeyPressedEvent.key === Qt.Key_Left) || (lastKeyPressedEvent.key === Qt.Key_Right)
          || (selectedText.length>0))) {
            const mention = d.getMentionAtPosition(cursorPosition)
            if (mention) {
                const cursorMovingLeft = (cursorPosition < previousCursorPosition);
                const newCursorPosition = cursorMovingLeft ?
                                            mention.leftIndex :
                                            mention.rightIndex
                const isSelection = (selectedText.length>0);
                isSelection ? moveCursorSelection(newCursorPosition, TextEdit.SelectCharacters) :
                              cursorPosition = newCursorPosition
            }
        }

        previousCursorPosition = cursorPosition
    }

    onTextChanged: {
        if (length <= messageInputField.messageLimit) {
            if (length === 0) {
                mentionsPos = [];
            } else {
                checkForInlineEmojis()
            }
        } else if (length > messageInputField.messageLimitHard) {
            const removeFrom = (cursorPosition < messageInputField.messageLimitHard) ? cursorWhenPressed : messageInputField.messageLimitHard;
            remove(removeFrom, cursorPosition);
            lengthLimitTooltip.open();
        }

        d.updateMentionsPositions()
        d.cleanMentionsPos()

        lengthLimitText.remainingChars = (messageInputField.messageLimit - length);
    }

    onLinkActivated: {
        const mention = d.getMentionAtPosition(cursorPosition - 1)
        if(mention) {
            select(mention.leftIndex, mention.rightIndex)
        }
    }

    StatusSyntaxHighlighter {
        quickTextDocument: messageInputField.textDocument
        codeBackgroundColor: Theme.palette.baseColor4
        codeForegroundColor: Theme.palette.textColor
        hyperlinks: messageInputField.urlsList
        hyperlinkColor: Theme.palette.primaryColor1
        highlightedHyperlink: linkPreviewArea.hoveredUrl
        hyperlinkHoverColor: Theme.palette.primaryColor3
    }
    StatusMouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        enabled: parent.hoveredLink
        cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor
    }
}
