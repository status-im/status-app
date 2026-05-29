"""Page object for group chat creation, messaging, and member management.

Complements :class:`ChatPage` — reuses the shared chat surface for
composing and reading messages, and adds group-specific actions
(create, rename, add/remove members, leave).

QML sources the locators derive from are documented inline in
``locators/messaging/group_chat_locators.py``. Every locator that could
not be grounded to a stable ``objectName`` at the time of writing is
tagged ``TODO: verify objectName`` — those should be revisited once
the relevant QML gets objectName'd.
"""

from __future__ import annotations

import time
from typing import List, Optional

from locators.messaging.chat_locators import ChatLocators
from locators.messaging.group_chat_locators import GroupChatLocators
from utils.timeouts import CROSS_DEVICE_DELIVERY_TIMEOUT_SECONDS

from ..base_page import BasePage
from .chat_page import ChatPage
from .create_chat_page import CreateChatPage


class GroupChatPage(BasePage):
    """Actions for group chats on mobile.

    Use :meth:`create_group_chat` from the admin/creator device; use
    :meth:`is_group_chat_visible` / :meth:`open_group_chat_by_name` from
    any member device once the group has propagated.
    """

    UI_TIMEOUT = 30
    CROSS_DEVICE_TIMEOUT = CROSS_DEVICE_DELIVERY_TIMEOUT_SECONDS
    MESSAGE_DELIVERY_TIMEOUT = CROSS_DEVICE_DELIVERY_TIMEOUT_SECONDS

    def __init__(self, driver):
        super().__init__(driver)
        self.locators = GroupChatLocators()
        self._chat_locators = ChatLocators()
        self._chat_page = ChatPage(driver)
        self._create_chat_page = CreateChatPage(driver)

    # ------------------------------------------------------------------
    # Group creation
    # ------------------------------------------------------------------

    def create_group_chat(
        self,
        group_name: str,
        members: List[str],
        *,
        timeout: int = UI_TIMEOUT,
    ) -> bool:
        """Create a group chat with *members* and *group_name*.

        The creator must already be on the chat-list screen. ``members`` is
        a list of display names of mutual contacts to include. The group
        name is what the desktop code computes as ``groupName.join("&")``
        automatically from selected members; mobile lets the user override
        it via a rename step after creation (see :meth:`set_group_name`).

        Returns True on apparent success (confirm button tapped and the
        modal closed). Delivery verification is a separate concern —
        callers should assert against the chat list using
        :meth:`is_group_chat_visible`.
        """
        self.logger.info(
            "Creating group chat %r with members=%s", group_name, members,
        )

        if not self._chat_page.tap_start_chat(timeout=timeout):
            self.logger.error("Could not open create-chat surface")
            return False

        for name in members:
            if not self.add_member_to_group(name, timeout=timeout):
                self.logger.error("Failed to add member %r", name)
                return False

        if not self.confirm_group_creation(timeout=timeout):
            self.logger.error("Confirm failed after adding members")
            return False

        self.logger.info("Create-group confirm tapped")
        return True

    def add_member_to_group(
        self,
        display_name: str,
        *,
        timeout: int = UI_TIMEOUT,
    ) -> bool:
        """Pick the next available contact from the create-chat picker.

        ``display_name`` is the caller's intent ("I want to add member X"),
        recorded in logs but NOT typed into the picker. Two reasons:

        1. ``CreateChatView.qml`` binds the contacts-list visibility to
           ``edit.text === ""`` — any keystroke in the input HIDES the
           suggestion list, leaving nothing to tap.
        2. The picker filters by alias/displayName/ensName/localNickname.
           Under fixture flows the contact's local display name is the
           receiver-side auto-derived Frilledlizard identity (e.g.
           "Unselfish Free Crocodile"), not the sender-side display_name
           the caller passes — so a typed filter would yield zero rows
           anyway.

        We tap the first available row from ``ANY_MEMBER_LIST_ITEM``.
        Status's ``notAMemberPredicate`` filters already-picked members
        out of the suggestions, so successive calls to this method pick
        distinct contacts in order.
        """
        self.logger.info(
            "Picking next member (intent=%r, unfiltered first-row tap)",
            display_name,
        )
        return self.safe_click(
            self.locators.ANY_MEMBER_LIST_ITEM,
            timeout=timeout,
            max_attempts=2,
        )

    def confirm_group_creation(self, *, timeout: int = UI_TIMEOUT) -> bool:
        """Tap the create-chat confirm footer button."""
        return self.safe_click(
            self.locators.CREATE_CHAT_CONFIRM_BUTTON,
            timeout=timeout,
            max_attempts=2,
        )

    def set_group_name(self, name: str, *, timeout: int = UI_TIMEOUT) -> bool:
        """Rename the currently open group chat.

        Requires the group's context menu to be opened first via
        :meth:`open_edit_group_menu` (or equivalent). For the whole
        rename-from-chat-list flow, use :meth:`rename_group_from_chat_list`.
        """
        if not self.is_element_visible(
            self.locators.RENAME_GROUP_POPUP, timeout=timeout,
        ):
            self.logger.error("Rename-group popup not visible")
            return False
        # verify=False: the rename input's a11y value doesn't read back on Pi,
        # and a pre-save echo wouldn't prove the rename saved anyway.
        if not self.qt_safe_input(
            self.locators.RENAME_GROUP_NAME_INPUT,
            name,
            timeout=timeout,
            verify=False,
        ):
            return False
        return self.safe_click(
            self.locators.RENAME_GROUP_SAVE_BUTTON, timeout=timeout,
        )

    # ------------------------------------------------------------------
    # Group management from the chat list's context menu
    # ------------------------------------------------------------------

    def open_chat_list_context_menu(
        self,
        group_name: str,
        *,
        timeout: int = UI_TIMEOUT,
        row_locator: Optional[tuple] = None,
    ) -> bool:
        """Long-press the row for *group_name* to open its context menu.

        Status's chat row uses a Qt clicked handler that triggers the
        popup menu on ``mouse.button === Qt.RightButton``. Touch
        long-press maps to right-click in Qt's touch translation layer,
        so a long-press gesture is the right primitive on mobile. The
        translation is timing-sensitive — too short and the press is
        interpreted as a click; too long and Qt may interpret it as
        a drag. We try escalating durations and verify the menu opened
        before returning.

        ``row_locator`` (preferred when caller has it) targets a row
        located via :meth:`find_group_row_by_exclusion`, bypassing the
        unreliable name-based ``group_chat_row_by_name`` lookup on Pi
        (where chat list rows have empty ``text``/``content-desc`` and
        the group name is hash-mangled in the resource-id path).

        Returns True if the context menu appears (any
        ``editNameAndImageMenuItem`` / ``deleteOrLeaveMenuItem`` /
        ``addRemoveFromGroupStatusAction`` becomes visible).
        """
        from locators.messaging.group_chat_locators import (
            GroupChatLocators as L,
        )
        menu_item_locators = [
            L.EDIT_GROUP_NAME_MENU_ITEM,
            L.DELETE_OR_LEAVE_MENU_ITEM,
            L.ADD_REMOVE_FROM_GROUP_ACTION,
        ]

        def _menu_open() -> bool:
            return any(
                self.is_element_visible(loc, timeout=1)
                for loc in menu_item_locators
            )

        row = row_locator or self.locators.group_chat_row_by_name(group_name)
        if not self.is_element_visible(row, timeout=timeout):
            if not self.scroll_to_element(row, max_swipes=3, timeout=3):
                self.logger.error(
                    "Group chat row %r not found in chat list", group_name,
                )
                return False

        # Escalating durations: Qt's touch→right-click translation is
        # timing-sensitive, so no single press length is reliable.
        for duration_ms in (800, 1200, 1600):
            element = self.find_element_safe(row, timeout=timeout)
            if element is None:
                self.logger.warning(
                    "Chat row %r vanished between long-press attempts",
                    group_name,
                )
                return False
            self.long_press_element(element, duration=duration_ms)
            if _menu_open():
                self.logger.info(
                    "Chat context menu opened after %dms long-press",
                    duration_ms,
                )
                return True
            self.logger.warning(
                "Long-press %dms did not open context menu; "
                "retrying with longer duration", duration_ms,
            )
        self.logger.error(
            "Context menu did not open for %r after 3 long-press attempts",
            group_name,
        )
        self.dump_page_source(f"context_menu_did_not_open_{group_name[:30]}")
        return False

    def open_group_context_menu_via_header(
        self,
        group_name: str,
        *,
        timeout: int = UI_TIMEOUT,
        row_locator: Optional[tuple] = None,
    ) -> bool:
        """Open the group's context menu via the in-chat header "More"
        button instead of the chat-list long-press.

        Opens the group chat, taps ``chatToolbarMoreOptionsButton``, and
        verifies the moreOptionsContextMenu (a ChatContextMenuView with
        the same item objectNames as the chat-list menu) is showing.

        Preferred on Pi: a plain tap is reliable where the chat-list
        long-press is timing-sensitive (Qt long-press → right-click
        translation intermittently auto-fires the top item or fails to
        register).
        """
        from locators.messaging.group_chat_locators import (
            GroupChatLocators as L,
        )
        if not self.open_group_chat_by_name(
            group_name, timeout=timeout, row_locator=row_locator,
        ):
            self.logger.error(
                "open_group_context_menu_via_header: could not open group chat"
            )
            return False
        if not self.safe_click(
            self.locators.CHAT_TOOLBAR_MORE_OPTIONS_BUTTON, timeout=timeout,
        ):
            self.logger.error(
                "open_group_context_menu_via_header: could not tap More button"
            )
            return False
        menu_item_locators = [
            L.EDIT_GROUP_NAME_MENU_ITEM,
            L.DELETE_OR_LEAVE_MENU_ITEM,
            L.ADD_REMOVE_FROM_GROUP_ACTION,
        ]
        if any(self.is_element_visible(loc, timeout=2) for loc in menu_item_locators):
            return True
        self.logger.error(
            "open_group_context_menu_via_header: menu did not open after tap"
        )
        return False

    def rename_group_from_chat_list(
        self,
        old_name: str,
        new_name: str,
        *,
        timeout: int = UI_TIMEOUT,
        row_locator: Optional[tuple] = None,
    ) -> bool:
        if not self.open_group_context_menu_via_header(
            old_name, timeout=timeout, row_locator=row_locator,
        ):
            return False
        if not self.safe_click(
            self.locators.EDIT_GROUP_NAME_MENU_ITEM, timeout=timeout,
        ):
            return False
        return self.set_group_name(new_name, timeout=timeout)

    def open_add_remove_members(
        self,
        group_name: str,
        *,
        timeout: int = UI_TIMEOUT,
        row_locator: Optional[tuple] = None,
    ) -> bool:
        """Open the add/remove-members sheet for *group_name*."""
        if not self.open_group_context_menu_via_header(
            group_name, timeout=timeout, row_locator=row_locator,
        ):
            return False
        return self.safe_click(
            self.locators.ADD_REMOVE_FROM_GROUP_ACTION, timeout=timeout,
        )

    def _tap_members_button(self, *, timeout: int = UI_TIMEOUT) -> bool:
        """Open the UserListPanel via the in-chat header Members button.

        The button has no objectName, so it's targeted by position: it
        sits immediately left of the (identifiable)
        chatToolbarMoreOptionsButton in the header toolbar.

        PI-ONLY / not cross-device robust: a relative-position tap won't
        survive header reflow on other screen sizes or BrowserStack
        (conditional button visibility + responsive layout). The robust
        fix is a one-line upstream objectName on ``membersButton`` —
        then this becomes a plain tid() tap.
        """
        if self.is_element_visible(self.locators.MEMBERS_BUTTON, timeout=2):
            return self.safe_click(self.locators.MEMBERS_BUTTON, timeout=timeout)
        more = self.find_element_safe(
            self.locators.CHAT_TOOLBAR_MORE_OPTIONS_BUTTON, timeout=timeout,
        )
        if more is None:
            self.logger.error(
                "_tap_members_button: neither Members nor More button found"
            )
            return False
        try:
            rect = more.rect
            gap = int(rect["width"] * 0.2)
            x = int(rect["x"] - gap - rect["width"] / 2)
            y = int(rect["y"] + rect["height"] / 2)
            self.gestures.tap(x, y)
        except Exception as exc:
            self.logger.error("_tap_members_button position tap failed: %s", exc)
            return False
        # The UserListPanel container's resource-id isn't reliably
        # exposed; its StatusMemberListItem rows are. Gate on those.
        any_member_row = (
            "xpath", "//*[contains(@resource-id,'StatusMemberListItem')]",
        )
        return self.is_element_visible(any_member_row, timeout=8)

    def remove_member(
        self,
        group_name: str,
        member_identity: str,
        *,
        timeout: int = UI_TIMEOUT,
        row_locator: Optional[tuple] = None,
    ) -> bool:
        """Remove the member named *member_identity* from *group_name* (admin).

        Uses the Members panel (UserListPanel), not the add/remove chip
        picker: open group → Members button → long-press the member's row
        (found by its content-desc identity name) → "Remove from group"
        (``removeFromGroup_StatusItem``). The chip picker can't be used —
        its member chips expose no per-member a11y identity.

        ``member_identity`` is the peer's Frilledlizard name (the same
        string Status shows in the panel and in the ``&``-joined
        auto-derived group name).
        """
        if not self.open_group_chat_by_name(
            group_name, timeout=timeout, row_locator=row_locator,
        ):
            return False
        if not self._tap_members_button(timeout=timeout):
            return False
        row = self.locators.member_panel_row_by_name(member_identity)
        for press_ms in (900, 1400):
            element = self.find_element_safe(row, timeout=timeout)
            if element is None:
                self.logger.error(
                    "remove_member: member row %r not found in panel",
                    member_identity,
                )
                return False
            # Long-press opens the member's ProfileDialog ON TOP of the
            # ProfileContextMenu. A removeFromGroup tap while the profile
            # covers the menu silently lands on the profile and the member
            # is never removed. Another user's profile has no close button
            # (ProfileDialog header is shown only for the current user), so
            # dismiss it with a back navigation — that leaves the context
            # menu open underneath, where removeFromGroup is reachable.
            self.long_press_element(element, duration=press_ms)
            time.sleep(1)
            self.driver.back()
            # safe_click raises (not returns False) on exhaustion, so gate on
            # visibility first — else a missed long-press skips the retry below.
            if self.is_element_visible(
                self.locators.REMOVE_FROM_GROUP_ITEM, timeout=5,
            ):
                return self.safe_click(
                    self.locators.REMOVE_FROM_GROUP_ITEM, timeout=timeout,
                )
            self.logger.warning(
                "remove_member: removeFromGroup not actioned after %dms "
                "long-press; retrying", press_ms,
            )
        return False

    def add_member_to_existing_group(
        self,
        group_name: str,
        member_identity: str,
        *,
        timeout: int = UI_TIMEOUT,
        row_locator: Optional[tuple] = None,
    ) -> bool:
        """Add the contact named *member_identity* back to *group_name* (admin).

        Opens the add/remove sheet (header More → add/remove from group) and
        re-adds via the inline member picker (MembersSelectorBase →
        InlineSelectorPanel): type into the recipient input to surface the
        contact's suggestion row, tap it, then confirm with Save Changes.

        The picker's suggestion list is hidden until the recipient input has
        text (``visible: edit.text !== ""``) — the OPPOSITE of the new-chat
        CreateChatView picker, which lists contacts when the input is empty.
        Typing filters by alias/displayName, so we type a token of the
        member's name. ``member_identity`` is the admin's local name for the
        peer (from the group name), which is what the filter matches against.
        ``timeout`` gates how long to wait for the suggestion: a just-removed
        member only re-appears once the removal has settled in the membership
        model, so a Waku-grade timeout (not a UI one) is needed.
        """
        if not self.open_add_remove_members(
            group_name, timeout=self.UI_TIMEOUT, row_locator=row_locator,
        ):
            return False
        token = member_identity.split()[0] if member_identity.split() else member_identity
        self.logger.info(
            "Re-adding member (intent=%r, search token=%r)", member_identity, token,
        )
        if not self.qt_safe_input(
            self.locators.MEMBER_PICKER_INPUT, token,
            timeout=self.UI_TIMEOUT, verify=False,
        ):
            return False
        suggestion = self.locators.ANY_MEMBER_LIST_ITEM
        if not self.is_element_visible(suggestion, timeout=timeout):
            _dump = self.dump_page_source("add_sheet_no_suggestion")
            self.logger.error(
                "add_member: no suggestion for %r after typing %r (waited %ss; "
                "dump %s)", member_identity, token, timeout, _dump,
            )
            return False
        if not self.safe_click(suggestion, timeout=self.UI_TIMEOUT):
            return False
        return self.safe_click(
            self.locators.CREATE_CHAT_CONFIRM_BUTTON, timeout=self.UI_TIMEOUT,
        )

    def leave_group(
        self,
        group_name: str,
        *,
        timeout: int = UI_TIMEOUT,
        row_locator: Optional[tuple] = None,
    ) -> bool:
        """Leave *group_name* as a non-admin member."""
        if not self.open_group_context_menu_via_header(
            group_name, timeout=timeout, row_locator=row_locator,
        ):
            return False
        if not self.safe_click(
            self.locators.DELETE_OR_LEAVE_MENU_ITEM, timeout=timeout,
        ):
            return False
        return self.safe_click(
            self.locators.LEAVE_CONFIRM_BUTTON, timeout=timeout,
        )

    # ------------------------------------------------------------------
    # Verification
    # ------------------------------------------------------------------

    def find_group_row_by_exclusion(
        self,
        known_one_to_one_names: List[str],
    ) -> Optional[tuple]:
        """Return a locator for the group row, identified by exclusion.

        On Pi (Android API 35), chat list rows have empty ``text`` and
        ``content-desc`` — the chat name lives only in the dotted
        ``resource-id`` path. The group's name is mangled (``&`` is
        replaced with a hash and the name is truncated), so the user-
        visible group name doesn't substring-match. The 1:1 chats
        expose the peer's identity name cleanly though, so we identify
        the group as "any StatusDraggableListItem whose name-segment
        is NOT one of the known 1:1 chat names".

        Returns a (strategy, selector) locator tuple usable with
        ``is_element_visible`` / ``safe_click`` / ``long_press_element``,
        or None if no group row is found.
        """
        if not known_one_to_one_names:
            # Nothing to exclude — the first row would always match, which is
            # the 1:1 with admin. Refuse rather than return the wrong chat.
            self.logger.error(
                "find_group_row_by_exclusion called with no known 1:1 names; "
                "cannot disambiguate the group row"
            )
            return None
        from appium.webdriver.common.appiumby import AppiumBy
        try:
            elements = self.driver.find_elements(
                AppiumBy.XPATH,
                "//*[contains(@resource-id,'StatusDraggableListItem')]",
            )
        except Exception as exc:
            self.logger.debug("find_group_row_by_exclusion list failed: %s", exc)
            return None
        excluded = set(known_one_to_one_names)
        for el in elements:
            try:
                rid = el.get_attribute("resource-id") or ""
            except Exception:
                continue
            if ".StatusDraggableListItem_" not in rid:
                continue
            prefix = rid.split(".StatusDraggableListItem_", 1)[0]
            chat_name = prefix.rsplit(".", 1)[-1] if "." in prefix else prefix
            if chat_name and chat_name not in excluded:
                escaped = chat_name.replace("'", "\\'")
                return (
                    "xpath",
                    "//*[contains(@resource-id,'StatusDraggableListItem')"
                    f" and contains(@resource-id,\"{escaped}\")]",
                )
        return None

    def is_group_chat_visible(
        self,
        group_name: str,
        *,
        timeout: int = CROSS_DEVICE_TIMEOUT,
        row_locator: Optional[tuple] = None,
    ) -> bool:
        """True if *group_name* is visible in the chat list.

        Uses the cross-device timeout by default — this assertion is
        usually the cross-device half of a message-delivery check.
        """
        row = row_locator or self.locators.group_chat_row_by_name(group_name)
        return self.is_element_visible(row, timeout=timeout)

    def open_group_chat_by_name(
        self,
        group_name: str,
        *,
        timeout: int = CROSS_DEVICE_TIMEOUT,
        row_locator: Optional[tuple] = None,
    ) -> bool:
        """Open the group chat named *group_name* from the chat list."""
        row = row_locator or self.locators.group_chat_row_by_name(group_name)
        if not self.is_element_visible(row, timeout=timeout):
            if not self.scroll_to_element(row, max_swipes=3, timeout=3):
                return False
        return self.safe_click(row, timeout=timeout)

    def get_group_name_from_header(
        self,
        *,
        timeout: int = UI_TIMEOUT,
    ) -> Optional[str]:
        """Read the group name from the open chat's header button.

        Requires the group chat to already be open. Polls until either
        the title attribute is non-empty or ``timeout`` elapses. The
        title (``chatContentModule.chatDetails.name``) populates
        asynchronously after the chat is opened — empty on first read
        is normal for ~1-2 seconds.
        """
        deadline = time.time() + max(1, timeout)
        last_value: Optional[str] = None
        # Qt accessibility surfaces the title only on the nested
        # statusChatInfoButtonNameText node, not the parent button.
        candidate_locators = (
            self.locators.CHAT_INFO_HEADER_NAME_TEXT,
            self.locators.CHAT_INFO_HEADER_BUTTON,
        )
        while time.time() < deadline:
            for locator in candidate_locators:
                element = self.find_element_safe(locator, timeout=1)
                if element is None:
                    continue
                for attr in ("content-desc", "text"):
                    try:
                        value = element.get_attribute(attr)
                        if value and value not in ("null", ""):
                            # Trim Qt's "[tid:...]" debug suffix.
                            stripped = value.strip()
                            if " [tid:" in stripped:
                                stripped = stripped.split(" [tid:", 1)[0].strip()
                            if stripped:
                                return stripped
                    except Exception:
                        continue
                last_value = "<empty attributes>"
            if last_value is None:
                last_value = "<element not present>"
            time.sleep(1)
        self.logger.warning(
            "get_group_name_from_header: gave up after %ss (last: %s)",
            timeout, last_value,
        )
        return None

    def count_members_in_panel(
        self,
        group_name: str,
        *,
        timeout: int = UI_TIMEOUT,
        row_locator: Optional[tuple] = None,
    ) -> int:
        """Count current members shown in the group's Members panel.

        Opens the group and the UserListPanel (header Members button) and
        counts ``StatusMemberListItem`` rows — the same surface
        :meth:`remove_member` navigates. The count includes every current
        member (admin included), matching the desktop members-list check.
        Returns -1 if the group or panel can't be opened, so a count
        assertion fails with a clear value rather than 0.
        """
        if not self.open_group_chat_by_name(
            group_name, timeout=timeout, row_locator=row_locator,
        ):
            return -1
        if not self._tap_members_button(timeout=timeout):
            return -1
        by, selector = self.locators.MEMBER_PANEL_ROW_ANY
        try:
            return len(self.driver.find_elements(by, selector))
        except Exception as exc:
            self.logger.debug("count_members_in_panel failed: %s", exc)
            return -1

    def is_removed_member_lockout_shown(
        self,
        *,
        timeout: int = UI_TIMEOUT,
    ) -> bool:
        """True if the open chat shows the not-a-member lockout.

        When a removed/non-member opens a group, the composer placeholder
        switches to "You need to be a member of this group to send
        messages" and sending is disabled — both bound to
        ``isUserAllowedToSendMessage == false`` in RootStore.qml. Detecting
        the placeholder text is equivalent to asserting the lockout state.
        Call this with the group chat already open.
        """
        return self.is_element_visible(
            self.locators.NOT_A_MEMBER_PLACEHOLDER, timeout=timeout,
        )
