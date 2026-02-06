from ..base_locators import BaseLocators, xpath_string


class MessageContextMenuLocators(BaseLocators):
    """Locators for the Message Context Menu (long-press on message).
    
    QML: ui/imports/shared/views/chat/MessageContextMenuView.qml
    
    Note: These locators rely on objectName properties added to StatusAction
    components in MessageContextMenuView.qml. The objectName maps to resource-id
    in Appium.
    """

    # Menu container - StatusMenu with objectName "MessageContextMenuView"
    MENU_CONTAINER = BaseLocators.resource_id_contains("MessageContextMenuView")

    # Primary actions - using resource-id from objectName
    # Note: resource-id has full path prefix (e.g., QGuiApplication.mainWindow...messageContextMenu_replyTo)
    # so we use resource_id_contains() instead of id()
    REPLY_TO = BaseLocators.resource_id_contains("messageContextMenu_replyTo")
    EDIT_MESSAGE = BaseLocators.resource_id_contains("messageContextMenu_edit")
    COPY_MESSAGE = BaseLocators.resource_id_contains("messageContextMenu_copy")
    COPY_MESSAGE_ID = BaseLocators.resource_id_contains("messageContextMenu_copyId")
    PIN_MESSAGE = BaseLocators.resource_id_contains("messageContextMenu_pin")
    MARK_AS_UNREAD = BaseLocators.resource_id_contains("messageContextMenu_markUnread")
    DELETE_MESSAGE = BaseLocators.resource_id_contains("messageContextMenu_delete")

    # Quick reaction emojis - direct children of MessageContextMenuView ScrollView
    # Accessible.name is set to emojiId (Unicode hex code) in EmojiReaction.qml
    # e.g., "1f600" for 😀, "1f44d" for 👍
    
    # Emoji code mapping (Unicode hex codes used in content-desc):
    # 😀 = 1f600, 😃 = 1f603, 😄 = 1f604, 😁 = 1f601, 😆 = 1f606
    # 👍 = 1f44d, 👎 = 1f44e, ❤️ = 2764, 😂 = 1f602, 😢 = 1f622, 😡 = 1f621
    
    # Quick reactions shown in the menu (varies by app configuration)
    REACTION_GRIN = BaseLocators.xpath(
        "//*[contains(@resource-id,'MessageContextMenuView')]"
        "//android.widget.Button[@content-desc='1f600']"
    )
    REACTION_SMILEY = BaseLocators.xpath(
        "//*[contains(@resource-id,'MessageContextMenuView')]"
        "//android.widget.Button[@content-desc='1f603']"
    )
    REACTION_SMILE = BaseLocators.xpath(
        "//*[contains(@resource-id,'MessageContextMenuView')]"
        "//android.widget.Button[@content-desc='1f604']"
    )
    REACTION_BEAM = BaseLocators.xpath(
        "//*[contains(@resource-id,'MessageContextMenuView')]"
        "//android.widget.Button[@content-desc='1f601']"
    )
    REACTION_LAUGH = BaseLocators.xpath(
        "//*[contains(@resource-id,'MessageContextMenuView')]"
        "//android.widget.Button[@content-desc='1f606']"
    )
    
    # Common reactions (may need to scroll or open picker)
    REACTION_THUMBS_UP = BaseLocators.xpath(
        "//*[contains(@resource-id,'MessageContextMenuView')]"
        "//android.widget.Button[@content-desc='1f44d']"
    )
    REACTION_THUMBS_DOWN = BaseLocators.xpath(
        "//*[contains(@resource-id,'MessageContextMenuView')]"
        "//android.widget.Button[@content-desc='1f44e']"
    )
    REACTION_HEART = BaseLocators.xpath(
        "//*[contains(@resource-id,'MessageContextMenuView')]"
        "//android.widget.Button[@content-desc='2764']"
    )
    REACTION_JOY = BaseLocators.xpath(
        "//*[contains(@resource-id,'MessageContextMenuView')]"
        "//android.widget.Button[@content-desc='1f602']"
    )
    REACTION_SAD = BaseLocators.xpath(
        "//*[contains(@resource-id,'MessageContextMenuView')]"
        "//android.widget.Button[@content-desc='1f622']"
    )
    REACTION_ANGRY = BaseLocators.xpath(
        "//*[contains(@resource-id,'MessageContextMenuView')]"
        "//android.widget.Button[@content-desc='1f621']"
    )
    
    # "Add reaction" button opens emoji picker
    ADD_REACTION_BUTTON = BaseLocators.content_desc_contains("Add reaction")

    # Delete message confirmation dialog
    DELETE_CONFIRMATION_DIALOG = BaseLocators.resource_id_contains(
        "DeleteMessageConfirmationPopup"
    )
    DELETE_CONFIRMATION_BUTTON = BaseLocators.resource_id_contains(
        "chatButtonsPanelConfirmDeleteMessageButton"
    )

    # Fallback locators using text (less stable, for compatibility)
    @staticmethod
    def action_by_text(text: str) -> tuple:
        """Fallback locator for menu action by visible text.
        
        Use when resource-id locators fail (e.g., older builds without objectName).
        """
        escaped = xpath_string(text)
        return BaseLocators.xpath(
            f"//*[contains(@resource-id,'MessageContextMenuView')]"
            f"//*[contains(@text,{escaped}) or contains(@content-desc,{escaped})]"
        )

    # Emoji character to Unicode hex code mapping
    EMOJI_TO_CODE = {
        "😀": "1f600", "😃": "1f603", "😄": "1f604", "😁": "1f601", "😆": "1f606",
        "👍": "1f44d", "👎": "1f44e", "❤": "2764", "❤️": "2764",
        "😂": "1f602", "😢": "1f622", "😡": "1f621",
    }

    @classmethod
    def quick_reaction_by_emoji(cls, emoji: str) -> tuple:
        """Locator for a quick reaction emoji button.
        
        Args:
            emoji: Either the emoji character (e.g., '👍') or hex code (e.g., '1f44d')
        """
        # Convert emoji character to hex code if needed
        code = cls.EMOJI_TO_CODE.get(emoji, emoji)
        return BaseLocators.xpath(
            f"//*[contains(@resource-id,'MessageContextMenuView')]"
            f"//android.widget.Button[@content-desc='{code}']"
        )


class EmojiPickerLocators(BaseLocators):
    """Locators for the Emoji Picker popup.
    
    QML: ui/imports/shared/status/StatusEmojiPopup.qml
    
    LIMITATION: Individual emoji items in the grid currently lack accessible
    identifiers (content-desc is empty, resource-id is generic). The emoji_by_character
    locator won't work until QML accessibility is added to the emoji grid items.
    
    Current workaround: Use search functionality to filter emojis, then tap by position.
    """

    # Popup container (android.app.AlertDialog)
    POPUP_CONTAINER = BaseLocators.resource_id_contains("StatusEmojiPopup")
    
    # Search input - objectName is "StatusEmojiPopup_searchBox" in QML
    SEARCH_INPUT = BaseLocators.resource_id_contains("StatusEmojiPopup_searchBox")
    
    # Search input wrapper (contains "Search" placeholder)
    SEARCH_INPUT_WRAPPER = BaseLocators.xpath(
        "//*[contains(@resource-id,'StatusEmojiPopup')]"
        "//*[contains(@content-desc,'Search')]"
    )
    
    # Scrollbar (for scrolling through emojis)
    SCROLLBAR = BaseLocators.resource_id_contains("StatusEmojiPopup.StatusScrollBar")
    
    # Individual emoji items - generic locator (all have same resource-id pattern)
    # Note: These lack identifying info, so we locate by grid position
    EMOJI_GRID_ITEM = BaseLocators.resource_id_contains("StatusEmojiPopup.QQuickItem")

    @staticmethod
    def emoji_by_character(emoji: str) -> tuple:
        """Locator for an emoji in the picker by character.
        
        WARNING: This locator requires QML accessibility fixes to work.
        Currently, emoji items have empty content-desc.
        
        TODO: Add Accessible.name to emoji grid items in StatusEmojiPopup.qml
        """
        return BaseLocators.xpath(
            f"//*[contains(@resource-id,'StatusEmojiPopup')]"
            f"//*[contains(@content-desc,'{emoji}')]"
        )
    
    @staticmethod
    def emoji_by_grid_position(index: int) -> tuple:
        """Locator for an emoji by its position in the grid (0-indexed).
        
        Use this as a workaround until emoji accessibility is added.
        Note: Position may vary based on recent emojis shown.
        """
        # Grid items start at index 1 in the AlertDialog children (after search box)
        return BaseLocators.xpath(
            f"(//*[contains(@resource-id,'StatusEmojiPopup.QQuickItem')])[{index + 1}]"
        )
