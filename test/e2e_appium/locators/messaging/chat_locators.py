from ..base_locators import BaseLocators, object_name_pred, xpath_string


class ChatLocators(BaseLocators):
    """Locators for 1x1/group chat list, composer, and chat actions.

    QML sources:
    - ui/imports/shared/status/StatusChatInput.qml
    - ui/app/AppLayouts/Chat/views/ChatHeaderContentView.qml
    - ui/imports/shared/views/chat/ChatContextMenuView.qml
    """

    CHAT_LIST = BaseLocators.xpath(f"//*[{object_name_pred('ContactsColumnView_chatList')}]")
    CHAT_SEARCH_BOX = BaseLocators.tid("statusBaseInput")
    CHAT_HEADER = BaseLocators.tid("ContactsColumnView_MessagesHeadline")
    TOOLBAR_BACK_BUTTON = BaseLocators.tid("toolBarBackButton")
    MESSAGE_INPUT = BaseLocators.resource_id_contains("messageInputField")
    # Tablet's BaseProxyPanel-based input sets objectName on QML buttons
    # (matching `.NAME`); phone's StatusChatInputToolBar doesn't, so the
    # same buttons surface as auto-named class identifiers
    # (`StatusChatInputSendButton_QMLTYPE_NNNN`) or identical `.ChatIcon`
    # resource-ids. Position [9] under StatusChatInputToolBar lands on
    # the emoji button on phone (XPath document-order is off-by-one vs
    # AT bounds order).
    # TODO(upstream): drop the position fallback once
    # StatusChatInputToolBar.qml sets objectName on each ChatIcon.
    # End-anchored substring on resource-id avoids prefix collisions with
    # longer object names. Inlined (not BaseLocators.tid()) so the union
    # with the phone-form-factor fallback after ``|`` can stay alongside.
    # TODO: extract a tid_or_phone() helper if more locators need this.
    SEND_BUTTON = BaseLocators.xpath(
        "//*[contains(@content-desc, '[tid:statusChatInputSendButton]') "
        "or substring(@resource-id, string-length(@resource-id) - 25) "
        "= '.statusChatInputSendButton']"
        " | "
        f"//*[{object_name_pred('StatusChatInputSendButton')}]"
    )
    EMOJI_BUTTON = BaseLocators.xpath(
        "//*[contains(@content-desc, '[tid:statusChatInputEmojiButton]') "
        "or substring(@resource-id, string-length(@resource-id) - 26) "
        "= '.statusChatInputEmojiButton']"
        " | "
        f"(//*[{object_name_pred('StatusChatInputToolBar')}]"
        f"//*[{object_name_pred('.ChatIcon')}])[9]"
    )
    COMMAND_BUTTON = BaseLocators.tid("statusChatInputCommandButton")
    CHAT_MORE_OPTIONS_BUTTON = BaseLocators.resource_id_contains("chatToolbarMoreOptionsButton")
    CHAT_MORE_OPTIONS_MENU = BaseLocators.resource_id_contains("moreOptionsContextMenu")
    # Use the 1:1 chat variant (clearHistoryMenuItem) — not the group variant
    # (clearHistoryGroupMenuItem). resource_id ends with the objectName.
    CLEAR_HISTORY_MENU_ITEM = BaseLocators.xpath(
        f"//*[{object_name_pred('clearHistoryMenuItem')} "
        f"and not{object_name_pred('GroupMenuItem')}]"
    )
    CLEAR_HISTORY_CONFIRM_BUTTON = BaseLocators.resource_id_contains(
        "clearChatConfirmationDialogClearButton"
    )
    # QML objectName: "deleteOrLeaveMenuItem" -- renders as "Close Chat" for 1x1 chats
    CLOSE_CHAT_MENU_ITEM = BaseLocators.resource_id_contains("deleteOrLeaveMenuItem")
    # QML confirmButtonObjectName in deleteChatConfirmationDialogComponent
    CLOSE_CHAT_CONFIRM_BUTTON = BaseLocators.resource_id_contains(
        "deleteChatConfirmationDialogDeleteButton"
    )
    ADD_IMAGE_ACTION = BaseLocators.tid("chatCommandMenu_addImage")
    CHAT_LOG_VIEW = BaseLocators.xpath(f"//*[{object_name_pred('chatLogView')}]")
    # The chat log's ListView has no accessibility node; its viewport is the
    # band between the toolbar's bottom edge and the composer panel's top edge.
    CHAT_TOOLBAR = BaseLocators.tid("statusToolBar")
    CHAT_INPUT_PANEL = BaseLocators.tid("statusChatInput")
    INTRODUCE_SKIP_BUTTON = BaseLocators.tid("introduceSkipStatusFlatButton")
    BACKUP_SKIP_BUTTON = BaseLocators.tid("backupMessageSkipStatusFlatButton")
    # QML: EnablePushNotificationsPopup.qml — "Maybe later" left footer button
    PUSH_NOTIF_LATER_BUTTON = BaseLocators.tid("btnPushNotificationsLater")
    # X close icon on any StatusDialog header — used to dismiss the
    # drawer-intro dialog, which has no dedicated skip button.
    # QML: StatusHeaderActions.qml objectName "headerActionsCloseButton"
    DIALOG_HEADER_CLOSE_BUTTON = BaseLocators.tid("headerActionsCloseButton")
    START_CHAT_BUTTON = BaseLocators.object_name_contains("startChatButton")

    CHAT_ROWS = BaseLocators.xpath(
        "//android.widget.Button[contains(@resource-id,'StatusDraggableListItem')]"
        " | //*[starts-with(name(),'XCUIElementType')][contains(@name,'.StatusDraggableListItem_')]"
    )
    CHAT_HEADER_NAME = BaseLocators.resource_id_contains("statusChatInfoButtonNameText")

    @staticmethod
    def chat_row(resource_id: str) -> tuple:
        return BaseLocators.xpath(f"//*[@resource-id={xpath_string(resource_id)}]")

    @staticmethod
    def chat_row_ios(name: str) -> tuple:
        return BaseLocators.xpath(f"//*[@name={xpath_string(name)}]")

    @staticmethod
    def chat_list_item(display_name: str) -> tuple:
        escaped = display_name.replace("'", "\\'")
        xpath = (
            f"//*[{object_name_pred('ContactsColumnView_chatList')}]"
            f"//*[contains(@text,\"{escaped}\") or contains(@content-desc,\"{escaped}\")]"
        )
        return BaseLocators.xpath(xpath)

    @staticmethod
    def message_text(content: str) -> tuple:
        escaped = content.replace('"', '\\"')
        xpath = (
            "//android.widget.EditText"
            f"[contains(@content-desc,\"{escaped}\")]"
            " | //XCUIElementTypeStaticText[contains(@name,'StatusTextMessage_chatText')"
            f" and contains(@label,\"{escaped}\")]"
        )
        return BaseLocators.xpath(xpath)

    @staticmethod
    def message_text_exact(content: str) -> tuple:
        escaped = content.replace('"', '\\"')
        xpath = (
            "//android.widget.EditText"
            f"[@content-desc=\"{escaped}\"]"
            " | //XCUIElementTypeStaticText[contains(@name,'StatusTextMessage_chatText')"
            f" and @label=\"{escaped}\"]"
        )
        return BaseLocators.xpath(xpath)

    @staticmethod
    def message_content_desc_any(content: str) -> tuple:
        """Match any element whose content-desc contains the message text.

        Broader fallback for devices where the sent message renders as
        a different element type than ``EditText``.
        """
        escaped = content.replace('"', '\\"')
        return BaseLocators.xpath(f"//*[{object_name_pred('chatMessageViewDelegate')}]//*[contains(@content-desc,\"{escaped}\")]")

    # Reply preview bar shown above the chat input when replying.
    # QML: StatusChatInputReplyArea (objectName "statusChatInputReplyArea")
    # on the tablet input; phone surfaces the auto-named class
    # "StatusChatInputReplyPanel_QMLTYPE_NNNN". Union handles both;
    # see EMOJI_BUTTON for the form-factor rationale.
    REPLY_PREVIEW = BaseLocators.xpath(
        "//*[contains(@content-desc, '[tid:statusChatInputReplyArea]') "
        "or substring(@resource-id, string-length(@resource-id) - 24) "
        "= '.statusChatInputReplyArea']"
        " | "
        f"//*[{object_name_pred('StatusChatInputReplyPanel')}]"
    )
    REPLY_CLOSE_BUTTON = BaseLocators.resource_id_contains("replyAreaCloseButton")
    # Edit tag close (StatusChatInput.qml) or the toolbar's cancel
    # (StatusChatInputToolBar.qml); which one the phone exposes is untested.
    EDIT_CLOSE_BUTTON = BaseLocators.xpath(
        f"//*[{object_name_pred('statusChatInputEditCloseButton')} "
        f"or {object_name_pred('statusChatInputEditCancelButton')}]"
    )
    REPLY_DETAILS = BaseLocators.tid("StatusMessage_replyDetails")
    REPLY_CORNER = BaseLocators.resource_id_contains("statusMessageReplyCorner")

    @staticmethod
    def reply_preview_for_user(username: str) -> tuple:
        """Locator for reply preview showing we're replying to a specific user."""
        return BaseLocators.xpath(
            f"//*[{object_name_pred('statusChatInputReplyArea')}]"
            f"[contains(@content-desc,'Replying to {username}')]"
        )

    @staticmethod
    def message_is_reply(content: str) -> tuple:
        """Locator for a message that shows the reply corner indicator."""
        escaped = content.replace('"', '\\"')
        return BaseLocators.xpath(
            f"//*[contains(@content-desc,'{escaped}')]/ancestor::*"
            f"//*[{object_name_pred('statusMessageReplyCorner')}]"
        )

    # Edited message indicator - "(edited)" text appended to message
    # The "(edited)" text is part of the message content-desc
    @staticmethod
    def message_with_edited_indicator(content: str) -> tuple:
        """Locator for a message that contains both the content and '(edited)' indicator."""
        escaped = content.replace('"', '\\"')
        return BaseLocators.xpath(
            f"//*[{object_name_pred('chatMessageViewDelegate')}]"
            f"//*[contains(@content-desc,'{escaped}') "
            f"and contains(@content-desc,'(edited)')]"
            # iOS: "(edited)" is appended to the message text's label.
            " | //XCUIElementTypeStaticText[contains(@name,'StatusTextMessage_chatText')"
            f" and contains(@label,'{escaped}') and contains(@label,'(edited)')]"
        )

    # Pinned message indicator - shows "Pinned by" text
    # QML: StatusPinMessageDetails has objectName "statusPinMessageDetails"
    # and Accessible.name "{pinnedMsgInfoText} {pinnedBy}"
    PINNED_INDICATOR = BaseLocators.resource_id_contains("statusPinMessageDetails")

    @staticmethod
    def pinned_indicator_by_user(username: str) -> tuple:
        """Locator for pinned indicator showing who pinned the message."""
        return BaseLocators.xpath(
            f"//*[{object_name_pred('statusPinMessageDetails')}]"
            f"[contains(@content-desc,'{username}')]"
        )

    @staticmethod
    def message_pinned_indicator(content: str) -> tuple:
        """Locator for pinned indicator near a specific message."""
        escaped = content.replace('"', '\\"')
        return BaseLocators.xpath(
            f"//*[contains(@content-desc,'{escaped}')]/ancestor::*"
            f"//*[{object_name_pred('statusPinMessageDetails')}]"
        )

    # Reaction on message - emoji reactions shown below the message
    # QML: StatusMessageEmojiReactions has objectName "statusMessageEmojiReactions"
    # Each reaction button has objectName "messageReaction_{emoji}" and Accessible.name "{emoji}"
    MESSAGE_REACTIONS_ROW = BaseLocators.resource_id_contains("statusMessageEmojiReactions")

    @staticmethod
    def reaction_on_message(emoji_code: str) -> tuple:
        """Locator for a reaction emoji displayed on a message (not in context menu).

        The reaction button has objectName "messageReaction_{emoji}" which maps to
        resource-id, and Accessible.name set to the emoji hex code (content-desc).

        Args:
            emoji_code: Unicode hex code (e.g., '1f600' for 😀)
        """
        # Look for reaction by resource-id (messageReaction_1f600) or content-desc (1f600)
        # Exclude context menu reactions by not being inside MessageContextMenuView
        return BaseLocators.xpath(
            f"//*[{object_name_pred(f'messageReaction_{emoji_code}')}]"
            f"[not(ancestor::*[{object_name_pred('MessageContextMenuView')}])]"
        )

    @staticmethod
    def reaction_on_message_with_text(content: str, emoji_code: str) -> tuple:
        """The reaction badge on the message carrying ``content``, so a badge an
        earlier test left on another message cannot satisfy the check."""
        return BaseLocators.xpath(
            f"//*[{object_name_pred('chatMessageViewDelegate')}]"
            f"[.//*[contains(@content-desc,{xpath_string(content)})]]"
            f"//*[{object_name_pred(f'messageReaction_{emoji_code}')}]"
            f"[not(ancestor::*[{object_name_pred('MessageContextMenuView')}])]"
            # iOS: the delegate is not an element and every message shares one
            # name path, so the badge belongs to the nearest message text above it.
            f" | //XCUIElementTypeButton[contains(@name,'.messageReaction_{emoji_code}')]"
            f"[preceding::XCUIElementTypeStaticText[contains(@name,'StatusTextMessage_chatText')][1]"
            f"[contains(@label,{xpath_string(content)})]]"
        )
