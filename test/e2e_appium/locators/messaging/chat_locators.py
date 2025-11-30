from ..base_locators import BaseLocators


class ChatLocators(BaseLocators):
    CHAT_LIST = BaseLocators.xpath("//*[contains(@resource-id,'ContactsColumnView_chatList')]")
    CHAT_SEARCH_BOX = BaseLocators.content_desc_contains("tid:statusBaseInput")
    CHAT_HEADER = BaseLocators.content_desc_contains(
        "[tid:ContactsColumnView_MessagesHeadline]"
    )
    TOOLBAR_BACK_BUTTON = BaseLocators.xpath(
        "//android.widget.Button[@content-desc=' [tid:toolBarBackButton]']"
    )
    MESSAGE_INPUT = BaseLocators.xpath(
        "//*[contains(@resource-id,'messageInputField') or contains(@content-desc,'Message')]"
    )
    SEND_BUTTON = BaseLocators.xpath(
        "//*[contains(@resource-id,'statusChatInputSendButton')]"
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


