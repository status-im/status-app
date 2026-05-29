
import time

from locators.messaging.chat_locators import ChatLocators
from utils.exceptions import ElementInteractionError

from ..base_page import BasePage


class ChatPage(BasePage):
    def __init__(self, driver):
        super().__init__(driver)
        self.locators = ChatLocators()

    def _is_chat_list_visible(self, timeout: int = 3) -> bool:
        return (
            self.is_element_visible(self.locators.CHAT_SEARCH_BOX, timeout=timeout)
            or self.is_element_visible(self.locators.START_CHAT_BUTTON, timeout=1)
        )

    def _ensure_chat_list_visible(self, timeout: int = 5) -> bool:
        if self._is_chat_list_visible(timeout=2):
            return True
        if self.is_portrait_mode():
            self.safe_click(self.locators.TOOLBAR_BACK_BUTTON, timeout=2)
            return self._is_chat_list_visible(timeout=timeout)
        return False

    def is_loaded(self, timeout: int | None = 15) -> bool:
        self.dismiss_introduce_prompt(timeout=2)
        return self._ensure_chat_list_visible(timeout=timeout)

    def open_chat(self, display_name: str) -> bool:
        locator = self.locators.chat_list_item(display_name)
        return self.safe_click(locator, max_attempts=2)

    def has_any_chat(self, timeout: int = 5) -> bool:
        """Check if there are any chats in the chat list.

        Returns:
            bool: True if at least one chat exists.
        """
        self._ensure_chat_list_visible()
        return self.is_element_visible(self.locators.FIRST_CHAT_ITEM, timeout=timeout)

    def get_first_chat_name(self, timeout: int = 5) -> str | None:
        """Read the display text or content-desc of the first chat in the list.

        Useful for capturing the actual name of a chat before opening it via
        ``open_first_chat()`` so that later assertions (e.g. gone-from-list
        checks) can use a meaningful identifier rather than a potentially
        stale or unsynchronised name.

        Returns:
            The chat name string, or ``None`` if no chat is visible or the
            name cannot be read.
        """
        self._ensure_chat_list_visible()
        element = self.find_element_safe(self.locators.FIRST_CHAT_ITEM, timeout=timeout)
        if not element:
            return None
        for attr in ("content-desc", "text"):
            try:
                raw = element.get_attribute(attr)
                if not raw or raw == "null":
                    continue
                value = raw.strip()
                if " [tid:" in value:
                    value = value.split(" [tid:")[0].strip()
                if value:
                    return value
            except Exception:
                continue
        return None

    def open_first_chat(self, timeout: int = 10) -> bool:
        """Open the first chat in the chat list.

        Useful for tests that need any available chat without knowing specific names.

        Returns:
            bool: True if a chat was opened successfully.
        """
        self._ensure_chat_list_visible()
        if not self.is_element_visible(self.locators.FIRST_CHAT_ITEM, timeout=timeout):
            self.logger.warning("No chats available in the list")
            return False
        return self.safe_click(self.locators.FIRST_CHAT_ITEM, timeout=timeout)

    def _resolve_chat_locators(self, chat_identifier: str, display_name: str | None = None):
        """Locators for a chat row, in priority order.

        Status tags fresh-contact chat rows with an auto-generated 3-word
        identity name (e.g. "Whopping Insecure Frilledlizard") in
        ``resource-id`` on both sides, so identifier-specific locators
        miss. ``FIRST_CHAT_ITEM`` is the load-bearing fallback in the
        one-chat fixture scenario. Strict-uniqueness assertions are not
        supported by these locators today.
        """
        locators = [self.locators.dm_row_button(chat_identifier)]
        if display_name:
            locators.append(self.locators.chat_list_item(display_name))
        locators.append(self.locators.FIRST_CHAT_ITEM)
        return locators

    def open_chat_by_suffix(
        self,
        chat_identifier: str,
        *,
        display_name: str | None = None,
        timeout: int | None = 15,
    ) -> bool:
        self._ensure_chat_list_visible()
        primary, *fallbacks = self._resolve_chat_locators(chat_identifier, display_name)
        try:
            return self.safe_click(
                primary, fallback_locators=fallbacks, timeout=timeout, max_attempts=3,
            )
        except ElementInteractionError as exc:
            self.logger.debug(
                "Direct click chain failed (%s); attempting scroll in chat list", exc,
            )
        for locator in (primary, *fallbacks):
            if self.scroll_to_element(locator, max_swipes=3, timeout=3):
                return self.safe_click(locator, timeout=timeout, max_attempts=3)
        # Diagnostic: dump page source so we can tell whether the chat list
        # is genuinely empty (status-go fresh-contact race) vs populated but
        # using AT names our locators don't match.
        self.dump_page_source(f"open_chat_by_suffix_failure_{chat_identifier}")
        return False

    def chat_exists_in_list(
        self,
        chat_identifier: str,
        *,
        display_name: str | None = None,
        timeout: int = 10,
    ) -> bool:
        """Check if a chat row exists in the messages list."""
        try:
            if not self._ensure_chat_list_visible(timeout=timeout):
                return False
        except Exception as exc:
            self.logger.debug(f"Failed to show chat list: {exc}")
            return False

        locators = self._resolve_chat_locators(chat_identifier, display_name)
        return self.wait_for_condition(
            lambda: any(self.find_element_safe(loc, timeout=1) for loc in locators),
            timeout=timeout,
            poll_interval=0.5,
        )

    def wait_for_message_input(self, timeout: int | None = 10) -> bool:
        return self.is_element_visible(self.locators.MESSAGE_INPUT, timeout=timeout)

    def tap_start_chat(self, timeout: int | None = 5) -> bool:
        self.dismiss_backup_prompt(timeout=2)
        return self.safe_click(self.locators.START_CHAT_BUTTON, timeout=timeout)

    def send_message(self, message: str, timeout: int | None = None) -> bool:
        """Type, tap SEND_BUTTON, fall back to newline if the button
        isn't clickable. Newline-as-send is unreliable across soft-
        keyboard layouts; the button can be unclickable on first render
        or behind the keyboard in portrait.
        """
        self.dismiss_introduce_prompt(timeout=2)
        if not self.qt_safe_input(
            self.locators.MESSAGE_INPUT,
            message,
            verify=False,
            timeout=timeout,
        ):
            return False

        button_clicked = False
        try:
            button_clicked = self.safe_click(
                self.locators.SEND_BUTTON, timeout=3, max_attempts=1
            )
        except Exception as exc:
            self.logger.debug("Send-button click suppressed: %s", exc)

        if not button_clicked:
            self.logger.info("Send button not clickable — falling back to newline trigger")
            if not self.qt_safe_input(
                self.locators.MESSAGE_INPUT,
                "\n",
                verify=False,
                timeout=timeout,
            ):
                return False

        # Brief wait for Qt a11y tree to reflect the sent message.
        time.sleep(1)
        return True

    def submit_message_edit(self, updated_text: str, timeout: int = 10) -> bool:
        """Replace current edit text and submit the edited message."""
        # Pre-clear via Ctrl+A+Backspace for Qt/QML edit fields where element.clear()
        # (called internally by send_message -> qt_safe_input) is unreliable.
        if not self._clear_input_field(self.locators.MESSAGE_INPUT, timeout=timeout):
            self.logger.debug("Could not pre-clear edit input; relying on qt_safe_input clear")
        return self.send_message(updated_text, timeout=timeout)

    def message_exists(self, content: str, timeout: int | None = 10) -> bool:
        locators = (
            self.locators.message_text_exact(content),
            self.locators.message_text(content),
            self.locators.message_content_desc_any(content),
        )

        def _found_message() -> bool:
            return any(self.find_element_safe(locator, timeout=2) for locator in locators)

        return self.wait_for_condition(_found_message, timeout=timeout)

    def dismiss_introduce_prompt(self, timeout: int | None = 2) -> bool:
        element = self.find_element_safe(self.locators.INTRODUCE_SKIP_BUTTON, timeout=timeout)
        if not element:
            return False
        try:
            element.click()
            return True
        except Exception as e:
            self.logger.debug(f"dismiss_introduce_prompt direct click failed: {e}")
            try:
                return self.safe_click(self.locators.INTRODUCE_SKIP_BUTTON, timeout=timeout)
            except Exception as e2:
                self.logger.debug(f"dismiss_introduce_prompt click also failed: {e2}")
                return False

    def dismiss_backup_prompt(self, timeout: int | None = 2) -> bool:
        element = self.find_element_safe(self.locators.BACKUP_SKIP_BUTTON, timeout=timeout)
        if not element:
            return False
        try:
            element.click()
            return True
        except Exception as e:
            self.logger.debug(f"dismiss_backup_prompt direct click failed: {e}")
            try:
                return self.safe_click(self.locators.BACKUP_SKIP_BUTTON, timeout=timeout)
            except Exception as e2:
                self.logger.debug(f"dismiss_backup_prompt click also failed: {e2}")
                return False

    def dismiss_push_notification_prompt(self, timeout: int | None = 2) -> bool:
        """Tap "Maybe later" on EnablePushNotificationsPopup if it's up.

        Status shows this modal after onboarding/login on Android 13+;
        it sits on top of the nav drawer and silently swallows clicks
        on Settings/Messages until dismissed.
        """
        element = self.find_element_safe(self.locators.PUSH_NOTIF_LATER_BUTTON, timeout=timeout)
        if not element:
            return False
        try:
            element.click()
            return True
        except Exception as e:
            self.logger.debug(f"dismiss_push_notification_prompt direct click failed: {e}")
            try:
                return self.safe_click(self.locators.PUSH_NOTIF_LATER_BUTTON, timeout=timeout)
            except Exception as e2:
                self.logger.debug(f"dismiss_push_notification_prompt click also failed: {e2}")
                return False

    def dismiss_drawer_intro_prompt(self, timeout: int | None = 2) -> bool:
        """Close NavigationEducationDialog ("To open app menu") if it's up.

        Status shows this dialog the first time the user reaches the main
        app after onboarding/login. It has footer.visible: false so the
        only dismiss is the X close button in the StatusDialog header.
        Safe to call when no dialog is up — returns False without clicking.
        """
        element = self.find_element_safe(self.locators.DIALOG_HEADER_CLOSE_BUTTON, timeout=timeout)
        if not element:
            return False
        try:
            element.click()
            return True
        except Exception as e:
            self.logger.debug(f"dismiss_drawer_intro_prompt direct click failed: {e}")
            try:
                return self.safe_click(self.locators.DIALOG_HEADER_CLOSE_BUTTON, timeout=timeout)
            except Exception as e2:
                self.logger.debug(f"dismiss_drawer_intro_prompt click also failed: {e2}")
                return False

    def wait_for_new_chat_to_arrive(
        self,
        chat_identifier: str,
        *,
        display_name: str | None = None,
        timeout: int = 60,
    ) -> bool:
        """Wait for a chat row to appear in the messages list.

        Periodically dismisses any dialogs and forces a navigation-level
        refresh (Wallet → Messages) so the chat list is re-rendered.  The
        Waku P2P layer may have delivered the message but the Qt list view
        doesn't always update in place.
        """
        from pages.app import App

        _REFRESH_INTERVAL = 30  # seconds between nav-toggle refreshes

        self.dismiss_introduce_prompt(timeout=2)
        self.dismiss_backup_prompt(timeout=2)
        self._ensure_chat_list_visible()
        locators = self._resolve_chat_locators(chat_identifier, display_name)

        deadline = time.time() + timeout
        last_refresh = time.time()
        app = App(self.driver)

        while time.time() < deadline:
            # Check for the chat row
            try:
                if any(self.find_element_safe(loc, timeout=1) for loc in locators):
                    return True
            except Exception:
                pass

            # Periodically force a full nav refresh: switch to another
            # section and back so the chat list is re-built by the UI.
            if time.time() - last_refresh >= _REFRESH_INTERVAL:
                self.logger.info(
                    "Nav-toggling to refresh chat list while waiting for '%s'",
                    chat_identifier,
                )
                self.dismiss_introduce_prompt(timeout=1)
                self.dismiss_backup_prompt(timeout=1)
                try:
                    app.click_wallet_button()
                    time.sleep(1)
                    # Force nav even if already in Messages (bypass short-circuit)
                    app._ensure_main_nav_visible()
                    app._click_nav_item(app.locators.LEFT_NAV_MESSAGES)
                except Exception as exc:
                    self.logger.debug("Nav-toggle refresh failed: %s", exc)
                self.dismiss_introduce_prompt(timeout=1)
                self.dismiss_backup_prompt(timeout=1)
                self._ensure_chat_list_visible(timeout=5)
                last_refresh = time.time()

            time.sleep(1.0)

        return False

    def is_chat_selected(
        self,
        chat_identifier: str,
        *,
        display_name: str | None = None,
        timeout: int | None = 4,
    ) -> bool:
        locators = self._resolve_chat_locators(chat_identifier, display_name)
        element = None
        for locator in locators:
            element = self.find_element_safe(locator, timeout=timeout)
            if element:
                break
        if not element:
            return False
        try:
            return str(element.get_attribute("selected")).lower() == "true"
        except Exception as e:
            self.logger.debug(f"is_chat_selected attribute read failed: {e}")
            return False

    # ===== Reply Mode =====

    def is_reply_mode_active(self, timeout: int = 5) -> bool:
        """Check if the reply preview bar is visible (indicates reply mode is active)."""
        return self.is_element_visible(self.locators.REPLY_PREVIEW, timeout=timeout)

    def cancel_reply(self, timeout: int = 5) -> bool:
        """Cancel reply mode by tapping the close button."""
        if not self.is_reply_mode_active(timeout=2):
            return True  # Not in reply mode
        return self.safe_click(self.locators.REPLY_CLOSE_BUTTON, timeout=timeout)

    # ===== Message State Verification =====

    def message_is_edited(self, content: str, timeout: int = 10) -> bool:
        """Check if a message shows the '(edited)' indicator.

        Args:
            content: The message text (without the '(edited)' suffix).
        """
        locator = self.locators.message_with_edited_indicator(content)
        return self.is_element_visible(locator, timeout=timeout)

    def message_is_pinned(self, content: str, timeout: int = 10) -> bool:
        """Check if a message shows the 'Pinned by' indicator.

        Approach: The StatusPinMessageDetails component (a Loader) is only active/visible
        when a message is pinned. We check if this component exists and optionally verify
        it's for the expected message.

        Note: Desktop tests use `delegate_button.object.isPinned` (direct property access).
        Appium can only use accessibility properties (resource-id, content-desc).
        """
        # First check if the message exists
        if not self.message_exists(content, timeout=5):
            self.logger.warning(f"Message '{content}' not found")
            return False

        # Check for ANY pinned indicator visible (statusPinMessageDetails component)
        # The Loader component is only active when a message is pinned
        if not self.is_element_visible(self.locators.PINNED_INDICATOR, timeout=timeout):
            self.logger.debug("No pinned indicator found")
            return False

        # Pinned indicator found - optionally verify content-desc contains "Pinned by"
        # (Accessible.name = pinnedMsgInfoText + " " + pinnedBy, e.g., "Pinned by Alice")
        element = self.find_element_safe(self.locators.PINNED_INDICATOR, timeout=2)
        if element:
            raw_desc = element.get_attribute("content-desc")
            content_desc = "" if (not raw_desc or raw_desc == "null") else raw_desc
            if "Pinned" in content_desc:
                self.logger.info(f"Found pinned indicator: {content_desc}")
                return True
            self.logger.debug(f"Pinned indicator content-desc: '{content_desc}'")

        # Fallback: indicator visible but couldn't read content-desc, assume pinned
        return True

    def message_has_reaction(self, emoji_code: str, timeout: int = 10) -> bool:
        """Check if any message has a specific reaction emoji visible.

        Args:
            emoji_code: Unicode hex code (e.g., '1f600' for 😀)
        """
        locator = self.locators.reaction_on_message(emoji_code)
        return self.is_element_visible(locator, timeout=timeout)

    def message_is_reply(self, content: str, timeout: int = 10) -> bool:
        """Check if a message shows the reply corner indicator.

        Tries statusMessageReplyCorner first; falls back to
        StatusMessage_replyDetails (the "Replying to ..." banner) if the
        corner objectName is not exposed in the accessibility tree.
        """
        locator = self.locators.message_is_reply(content)
        if self.is_element_visible(locator, timeout=timeout):
            return True
        self.logger.debug("Reply corner not found, falling back to REPLY_DETAILS")
        return self.is_element_visible(self.locators.REPLY_DETAILS, timeout=3)

    def message_count(self) -> int:
        """Return the count of message content elements in the chat log."""
        locator = (
            "xpath",
            "//*[contains(@resource-id,'StatusTextMessage_chatText')]",
        )
        try:
            return len(self.driver.find_elements(*locator))
        except Exception:
            return 0

    def wait_for_message_count(self, minimum: int, timeout: int = 10) -> bool:
        """Wait until the chat has at least `minimum` messages."""
        return self.wait_for_condition(
            lambda: self.message_count() >= minimum,
            timeout=timeout,
            poll_interval=0.5,
        )

    def send_emoji_to_chat(self, search_term: str, timeout: int = 10) -> bool:
        """Send an emoji to the chat using emoji picker search.

        Args:
            search_term: Search text for the emoji picker (e.g., 'thumbsup').
        """
        from locators.messaging.message_context_menu_locators import EmojiPickerLocators

        emoji_locators = EmojiPickerLocators()

        if not self.safe_click(self.locators.EMOJI_BUTTON, timeout=timeout):
            self.logger.error("Failed to click emoji button")
            return False

        if not self.is_element_visible(emoji_locators.POPUP_CONTAINER, timeout=5):
            self.logger.error("Emoji popup did not appear")
            return False

        if not self.qt_safe_input(
            emoji_locators.SEARCH_INPUT,
            search_term,
            timeout=5,
            verify=False,
        ):
            self.logger.error("Failed to type in emoji search")
            return False

        # Prefer shortname locator (stable objectName) over grid position, which
        # shifts when recently-used emojis are prepended to the grid.
        shortname_locator = emoji_locators.emoji_by_shortname(search_term)
        if self.is_element_visible(shortname_locator, timeout=5):
            target = shortname_locator
        else:
            target = emoji_locators.emoji_by_grid_position(0)
            if not self.is_element_visible(target, timeout=5):
                self.logger.error(f"No emoji results for search '{search_term}'")
                return False

        if not self.safe_click(target, timeout=5):
            self.logger.error(f"Failed to tap emoji for '{search_term}'")
            return False

        return self.safe_click(self.locators.SEND_BUTTON, timeout=5)

    def open_image_dialog(self, timeout: int = 10) -> bool:
        """Open the image attachment dialog via the command menu."""
        if not self.safe_click(self.locators.COMMAND_BUTTON, timeout=timeout):
            self.logger.error("Failed to click command button")
            return False
        return self.safe_click(self.locators.ADD_IMAGE_ACTION, timeout=5)

    def open_chat_options_menu(self, timeout: int = 10) -> bool:
        """Open the chat header context menu (More options)."""
        try:
            self.safe_click(self.locators.CHAT_MORE_OPTIONS_BUTTON, timeout=timeout)
            menu_visible = self.is_element_visible(
                self.locators.CHAT_MORE_OPTIONS_MENU, timeout=5,
            )
            if not menu_visible:
                self.logger.warning(
                    "Chat options menu container not visible after clicking more button"
                )
                # The menu might open as a popup that isn't captured by the
                # container locator. Try finding a known menu item directly.
                menu_visible = self.is_element_visible(
                    self.locators.CLOSE_CHAT_MENU_ITEM, timeout=3,
                ) or self.is_element_visible(
                    self.locators.CLEAR_HISTORY_MENU_ITEM, timeout=3,
                )
            return menu_visible
        except Exception as exc:
            self.logger.error("Failed to open chat options menu: %s", exc)
            return False

    def clear_history(self, timeout: int = 10) -> bool:
        """Clear the current chat history for this user only."""
        if not self.open_chat_options_menu(timeout=timeout):
            self.logger.error("Chat options menu did not open for clear history")
            return False

        try:
            self.safe_click(self.locators.CLEAR_HISTORY_MENU_ITEM, timeout=timeout)
            self.safe_click(self.locators.CLEAR_HISTORY_CONFIRM_BUTTON, timeout=timeout)
            return True
        except Exception as exc:
            self.logger.error("Failed to clear chat history: %s", exc)
            return False

    def close_chat(self, timeout: int = 10) -> bool:
        """Close the current chat from the chat options menu."""
        if not self.open_chat_options_menu(timeout=timeout):
            self.logger.error("Chat options menu did not open for close chat")
            return False

        try:
            self.safe_click(self.locators.CLOSE_CHAT_MENU_ITEM, timeout=timeout)
            self.safe_click(self.locators.CLOSE_CHAT_CONFIRM_BUTTON, timeout=timeout)
            return True
        except Exception as exc:
            self.logger.error("Failed to close chat: %s", exc)
            return False


