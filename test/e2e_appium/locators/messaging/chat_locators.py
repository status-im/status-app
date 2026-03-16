from ..base_locators import BaseLocators


class ChatLocators(BaseLocators):
    """Locators for 1x1/group chat list, composer, and chat actions.

    QML sources:
    - ui/imports/shared/status/StatusChatInput.qml
    - ui/app/AppLayouts/Chat/views/ChatHeaderContentView.qml
    - ui/imports/shared/views/chat/ChatContextMenuView.qml
    """

    CHAT_LIST = BaseLocators.xpath("//*[contains(@resource-id,'ContactsColumnView_chatList')]")
    CHAT_SEARCH_BOX = BaseLocators.content_desc_contains("tid:statusBaseInput")
    CHAT_HEADER = BaseLocators.content_desc_contains(
        "[tid:ContactsColumnView_MessagesHeadline]"
    )
    TOOLBAR_BACK_BUTTON = BaseLocators.xpath(
        "//android.widget.Button[@content-desc=' [tid:toolBarBackButton]']"
    )
    MESSAGE_INPUT = BaseLocators.resource_id_contains("messageInputField")
    SEND_BUTTON = BaseLocators.xpath(
        "//*[contains(@resource-id,'statusChatInputSendButton')]"
    )
    EMOJI_BUTTON = BaseLocators.xpath(
        "//*[contains(@content-desc, '[tid:statusChatInputEmojiButton]') or "
        "contains(@resource-id,'statusChatInputEmojiButton')]"
    )
    COMMAND_BUTTON = BaseLocators.xpath(
        "//*[contains(@content-desc, '[tid:statusChatInputCommandButton]') or "
        "contains(@resource-id,'statusChatInputCommandButton')]"
    )
    CHAT_MORE_OPTIONS_BUTTON = BaseLocators.resource_id_contains("chatToolbarMoreOptionsButton")
    CHAT_MORE_OPTIONS_MENU = BaseLocators.resource_id_contains("moreOptionsContextMenu")
    # Use the 1:1 chat variant (clearHistoryMenuItem) — not the group variant
    # (clearHistoryGroupMenuItem). resource_id ends with the objectName.
    CLEAR_HISTORY_MENU_ITEM = BaseLocators.xpath(
        "//*[contains(@resource-id,'clearHistoryMenuItem') "
        "and not(contains(@resource-id,'GroupMenuItem'))]"
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
    ADD_IMAGE_ACTION = BaseLocators.xpath(
        "//*[contains(@content-desc, '[tid:chatCommandMenu_addImage]') or "
        "contains(@resource-id,'chatCommandMenu_addImage')]"
    )
    CHAT_LOG_VIEW = BaseLocators.xpath("//*[contains(@resource-id,'chatLogView')]")
    INTRODUCE_SKIP_BUTTON = BaseLocators.content_desc_contains(
        "[tid:introduceSkipStatusFlatButton]"
    )
    BACKUP_SKIP_BUTTON = BaseLocators.content_desc_contains(
        "[tid:backupMessageSkipStatusFlatButton]"
    )
    START_CHAT_BUTTON = BaseLocators.xpath(
        "//*[contains(@resource-id,'startChatButton')]"
    )
    
    # First chat item in the list (for open_first_chat)
    FIRST_CHAT_ITEM = BaseLocators.xpath(
        "(//android.widget.Button[contains(@resource-id,'StatusDraggableListItem')])[1]"
    )

    @staticmethod
    def dm_row_button(chat_identifier: str) -> tuple:
        escaped = chat_identifier.replace("'", "\\'")
        xpath = (
            "//android.widget.Button[contains(@resource-id,'StatusDraggableListItem')]"
            f"[(contains(@resource-id,\"{escaped}\") or contains(@content-desc,\"{escaped}\")"
            f" or contains(@text,\"{escaped}\"))]"
        )
        return BaseLocators.xpath(xpath)

    @staticmethod
    def chat_list_item(display_name: str) -> tuple:
        escaped = display_name.replace("'", "\\'")
        xpath = (
            "//*[contains(@resource-id,'ContactsColumnView_chatList')]"
            f"//*[contains(@text,\"{escaped}\") or contains(@content-desc,\"{escaped}\")]"
        )
        return BaseLocators.xpath(xpath)

    @staticmethod
    def message_text(content: str) -> tuple:
        escaped = content.replace('"', '\\"')
        xpath = (
            "//android.widget.EditText"
            f"[contains(@content-desc,\"{escaped}\")]"
        )
        return BaseLocators.xpath(xpath)

    @staticmethod
    def message_text_exact(content: str) -> tuple:
        escaped = content.replace('"', '\\"')
        xpath = (
            "//android.widget.EditText"
            f"[@content-desc=\"{escaped}\"]"
        )
        return BaseLocators.xpath(xpath)

    @staticmethod
    def message_content_desc_any(content: str) -> tuple:
        """Match any element whose content-desc contains the message text.

        Broader fallback for devices where the sent message renders as
        a different element type than ``EditText``.
        """
        escaped = content.replace('"', '\\"')
        return BaseLocators.xpath(f"//*[contains(@content-desc,\"{escaped}\")]")

    # Reply mode indicator - when replying, there's a reply preview bar
    # QML: StatusChatInputReplyArea has objectName "statusChatInputReplyArea"
    # and Accessible.name "Replying to {userName}"
    REPLY_PREVIEW = BaseLocators.resource_id_contains("statusChatInputReplyArea")
    REPLY_CLOSE_BUTTON = BaseLocators.resource_id_contains("replyAreaCloseButton")
    REPLY_DETAILS = BaseLocators.xpath(
        "//*[contains(@content-desc, '[tid:StatusMessage_replyDetails]') or "
        "contains(@resource-id,'StatusMessage_replyDetails')]"
    )
    REPLY_CORNER = BaseLocators.resource_id_contains("statusMessageReplyCorner")
    
    @staticmethod
    def reply_preview_for_user(username: str) -> tuple:
        """Locator for reply preview showing we're replying to a specific user."""
        return BaseLocators.xpath(
            f"//*[contains(@resource-id,'statusChatInputReplyArea')]"
            f"[contains(@content-desc,'Replying to {username}')]"
        )

    @staticmethod
    def message_is_reply(content: str) -> tuple:
        """Locator for a message that shows the reply corner indicator."""
        escaped = content.replace('"', '\\"')
        return BaseLocators.xpath(
            f"//*[contains(@content-desc,'{escaped}')]/ancestor::*"
            f"//*[contains(@resource-id,'statusMessageReplyCorner')]"
        )
    
    # Edited message indicator - "(edited)" text appended to message
    # The "(edited)" text is part of the message content-desc
    @staticmethod
    def message_with_edited_indicator(content: str) -> tuple:
        """Locator for a message that contains both the content and '(edited)' indicator."""
        escaped = content.replace('"', '\\"')
        return BaseLocators.xpath(
            f"//android.widget.EditText[contains(@content-desc,'{escaped}') "
            f"and contains(@content-desc,'(edited)')]"
        )
    
    # Pinned message indicator - shows "Pinned by" text
    # QML: StatusPinMessageDetails has objectName "statusPinMessageDetails"
    # and Accessible.name "{pinnedMsgInfoText} {pinnedBy}"
    PINNED_INDICATOR = BaseLocators.resource_id_contains("statusPinMessageDetails")
    
    @staticmethod
    def pinned_indicator_by_user(username: str) -> tuple:
        """Locator for pinned indicator showing who pinned the message."""
        return BaseLocators.xpath(
            f"//*[contains(@resource-id,'statusPinMessageDetails')]"
            f"[contains(@content-desc,'{username}')]"
        )
    
    @staticmethod
    def message_pinned_indicator(content: str) -> tuple:
        """Locator for pinned indicator near a specific message."""
        escaped = content.replace('"', '\\"')
        return BaseLocators.xpath(
            f"//*[contains(@content-desc,'{escaped}')]/ancestor::*"
            f"//*[contains(@resource-id,'statusPinMessageDetails')]"
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
            f"//*[contains(@resource-id,'messageReaction_{emoji_code}')]"
            f"[not(ancestor::*[contains(@resource-id,'MessageContextMenuView')])]"
        )


