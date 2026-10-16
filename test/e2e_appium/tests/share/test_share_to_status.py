"""Content shared from another Android app reaches Status and the chats the user picks."""

import asyncio
import math
import time
import uuid

import pytest

from pages.app import App
from pages.messaging.chat_page import ChatPage
from pages.messaging.group_chat_page import GroupChatPage
from pages.onboarding.welcome_back_page import WelcomeBackPage
from pages.share_picker_page import SharePickerPage
from support import share_intents
from support.screen_identity import dismiss_backup_modal
from tests.messaging.peer_base import PeerChatBase

IMAGE_CONTENT_TYPE = 7
RUNNING_IN_BACKGROUND = 3
PICKER_TIMEOUT = 30
NO_PICKER_TIMEOUT = 8
PARKED_SHARE_TIMEOUT = 90
ECHO_TIMEOUT = 15
HOME_KEY = 3


def _unique(prefix: str) -> str:
    return f"{prefix}-{uuid.uuid4().hex[:8]}"


@pytest.mark.portrait
@pytest.mark.device_count(1)
@pytest.mark.timeout(1200)
class TestShareToStatus(PeerChatBase):
    """Shares arrive by intent, matched against Status's manifest filters as the
    system share sheet does; the peer is every chat's other member and confirms
    what was sent."""

    @property
    def package(self) -> str:
        return share_intents.package_of(self.driver)

    @property
    def dm_chat_id(self) -> str:
        return self.peer.public_key

    def share_page(self) -> SharePickerPage:
        return SharePickerPage(self.driver)

    def open_picker_with_text(self, text: str) -> SharePickerPage:
        share_intents.share_text(self.driver, text)
        page = self.share_page()
        assert page.is_open(timeout=PICKER_TIMEOUT), "The share screen did not open"
        return page

    async def tick(self, page: SharePickerPage, chat_id: str) -> None:
        await self.await_on_phone(
            page, chat_id,
            probe=lambda timeout: page.wait_for_destination(chat_id, timeout=timeout),
            describe=f"Chat {chat_id[:16]}… on the share screen",
        )
        page.select(chat_id)
        assert page.wait_for_selected(chat_id, True), f"Chat {chat_id[:16]}… did not get a tick"

    async def send_to(self, page: SharePickerPage, *chat_ids: str) -> float:
        """Tick the chats, tap Send, and return when the picker has gone."""
        for chat_id in chat_ids:
            await self.tick(page, chat_id)
        assert page.wait_for_send_enabled(True), "Send stayed disabled with chats ticked"
        page.tap_send()
        sent_at = time.monotonic()
        assert page.wait_closed(timeout=15), "The share screen stayed open after Send"
        return sent_at

    def leave_picker(self, page: SharePickerPage) -> None:
        """Cancel puts Status behind the sharing app; bring it back for the next step."""
        page.tap_cancel()
        assert page.wait_closed(timeout=15), "The share screen stayed open after Cancel"
        self.driver.activate_app(self.package)

    def leave_the_chat(self) -> None:
        chat_page = self.open_chat_list()
        assert not chat_page.wait_for_message_input(timeout=3), "A chat is still open"

    def assert_open_chat_is_the_1to1(self, context: str = "") -> None:
        header = GroupChatPage(self.driver).get_group_name_from_header(timeout=15) or ""
        assert any(name in header for name in (self.peer.display_name, self.peer.alias)), (
            f"The open chat is {header!r}, not the 1:1 with the peer{context}"
        )

    def relaunch_to_login(self) -> WelcomeBackPage:
        welcome = WelcomeBackPage(self.driver)
        assert welcome.app_lifecycle.terminate_app(self.package), "Status did not stop"
        welcome.app_lifecycle.activate_app_with_ui_ready(activation_timeout=15.0)
        assert welcome.is_welcome_back_screen_displayed(timeout=30), "No login screen after the relaunch"
        return welcome

    def log_in_to_picker(self, welcome: WelcomeBackPage) -> SharePickerPage:
        """Log in and return the share screen that a parked share opens."""
        assert welcome.perform_login(self.device.user.password), "Login failed"
        page = self.share_page()
        assert page.is_open(timeout=PARKED_SHARE_TIMEOUT), "The share screen did not open after login"
        dismiss_backup_modal(page, timeout=10)
        return page

    def on_peer(self, chat_id: str) -> str:
        """The peer keys the 1:1 by the phone's key; a group has one id on both sides."""
        return self.phone_key if chat_id == self.dm_chat_id else chat_id

    async def await_in_chats(self, chat_ids: list[str], text: str) -> None:
        await asyncio.gather(*(
            self.peer.await_message_in(self.on_peer(chat_id), text, timeout=self.CROSS_DEVICE_TIMEOUT)
            for chat_id in chat_ids
        ))

    def wait_for_app_state(self, state: int, timeout: int = 10) -> bool:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if self.driver.query_app_state(self.package) == state:
                return True
            time.sleep(0.5)
        return False

    @pytest.mark.spec("SC-SHARE-27")
    async def test_status_link_opened_with_status_keeps_its_deep_link_meaning(self) -> None:
        """A status.app link handed to Status as a web link opens the chat it names."""
        self.leave_the_chat()
        share_intents.open_link(self.driver, f"https://status.app/p/{self.peer.public_key}")
        assert ChatPage(self.driver).wait_for_message_input(timeout=30), "The link did not open a chat"
        self.assert_open_chat_is_the_1to1()

    @pytest.mark.spec("SC-SHARE-27")
    @pytest.mark.skip(
        reason="with UIAutomator2 attached the app stops answering once the link opens the "
        "browser (Samsung A36); the same link opened by hand works",
    )
    async def test_web_link_opened_with_status_shows_in_its_browser(self) -> None:
        """An http link handed to Status opens in its browser."""
        app = App(self.driver)
        share_intents.open_link(self.driver, "https://example.com/")
        assert app.wait_for_condition(lambda: app.active_section() == "browser", timeout=20), (
            f"Status is on {app.active_section()!r}, not in the browser"
        )
        address = self.share_page().browser_address()
        assert address and "example.com" in address, f"The address bar shows {address!r}"

    @pytest.mark.spec("SC-SHARE-01")
    async def test_text_link_image_and_captioned_image_reach_the_chat(self) -> None:
        """Status takes text, a link, an image and a captioned image through its
        share filters, and each arrives in the chosen chat."""
        for payload in (_unique("share-text"), f"https://example.com/{_unique('page')}"):
            async with self.step(f"Share {payload!r} to the peer's chat"):
                page = self.open_picker_with_text(payload)
                await self.send_to(page, self.dm_chat_id)
                await self.await_on_peer(payload)

        async with self.step("Share one image"):
            known = self.peer_message_ids()
            uri = share_intents.push_image(self.driver, _unique("share") + ".png")
            share_intents.share_image(self.driver, uri)
            page = self.share_page()
            assert page.is_open(timeout=PICKER_TIMEOUT), "The share screen did not open for an image"
            await self.send_to(page, self.dm_chat_id)
            message = await self.await_new_message_on_peer(known)
            assert message.get("contentType") == IMAGE_CONTENT_TYPE, f"The peer got {message!r}"

        async with self.step("Share an image with a caption"):
            caption = _unique("caption")
            share_intents.share_image(self.driver, uri, caption=caption)
            page = self.share_page()
            assert page.is_open(timeout=PICKER_TIMEOUT), "The share screen did not open for a captioned image"
            await self.send_to(page, self.dm_chat_id)
            message = await self.await_on_peer(caption)
            assert message.get("contentType") == IMAGE_CONTENT_TYPE, f"The caption arrived without its image: {message!r}"

    @pytest.mark.spec("SC-SHARE-05")
    async def test_share_opens_the_picker_when_open_backgrounded_and_closed(self) -> None:
        """The share screen opens whether Status is in front, in the background or not running."""
        async with self.step("Share while Status is open on a chat"):
            page = self.open_picker_with_text(_unique("open"))
            page.tap_cancel()
            assert page.wait_closed(timeout=15), "The share screen stayed open after Cancel"

        async with self.step("Share while Status is in the background"):
            assert self.wait_for_app_state(RUNNING_IN_BACKGROUND), "Status is not in the background"
            page = self.open_picker_with_text(_unique("background"))
            page.tap_cancel()
            assert page.wait_closed(timeout=15), "The share screen stayed open after Cancel"

        async with self.step("Share while Status is closed"):
            assert page.app_lifecycle.terminate_app(self.package), "Status did not stop"
            text = _unique("closed")
            share_intents.share_text(self.driver, text)
            welcome = WelcomeBackPage(self.driver)
            welcome.app_lifecycle.activate_app_with_ui_ready(activation_timeout=15.0)
            assert welcome.is_welcome_back_screen_displayed(timeout=30), "No login screen after the cold start"
            page = self.log_in_to_picker(welcome)
            await self.send_to(page, self.dm_chat_id)
            await self.await_on_peer(text)

    @pytest.mark.spec("SC-SHARE-06")
    async def test_share_before_login_waits_for_login(self) -> None:
        """A share at the login screen opens only after login, and sends."""
        text = _unique("prelogin")
        welcome = self.relaunch_to_login()
        page = self.share_page()

        async with self.step("Share at the login screen"):
            share_intents.share_text(self.driver, text)
            assert not page.is_open(timeout=NO_PICKER_TIMEOUT), "The share screen opened before login"
            assert welcome.is_welcome_back_screen_displayed(timeout=5), "The login screen went away"

        async with self.step("Log in; the share opens and sends"):
            page = self.log_in_to_picker(welcome)
            await self.send_to(page, self.dm_chat_id)
            await self.await_on_peer(text)

    @pytest.mark.spec("SC-SHARE-29")
    async def test_second_share_before_login_replaces_the_first(self) -> None:
        """Of two shares at the login screen, only the newest opens after login."""
        first, second = _unique("first"), _unique("second")
        welcome = self.relaunch_to_login()
        page = self.share_page()

        async with self.step("Share twice at the login screen"):
            share_intents.share_text(self.driver, first)
            share_intents.share_text(self.driver, second)
            assert not page.is_open(timeout=NO_PICKER_TIMEOUT), "The share screen opened before login"

        async with self.step("Log in; the newest share is sent and no other share opens"):
            page = self.log_in_to_picker(welcome)
            await self.send_to(page, self.dm_chat_id)
            await self.await_on_peer(second)
            assert not page.is_open(timeout=NO_PICKER_TIMEOUT), "A second share screen opened"
            assert self.peer.find_message(self.phone_key, first) is None, f"{first!r} reached the peer"

    @pytest.mark.spec("SC-SHARE-04")
    async def test_share_reopened_from_recents_does_not_open_again(self) -> None:
        """Reopened from Recents after its process died, an app gets its task's
        first intent again, flagged as a history launch. A share that arrives
        that way was handled before and must not open a second time. The same
        share without the flag opens after login (SC-SHARE-05, closed step)."""
        replayed, fresh = _unique("replayed"), _unique("fresh")
        page = self.share_page()

        async with self.step("Start Status from a share flagged as a Recents launch"):
            assert page.app_lifecycle.terminate_app(self.package), "Status did not stop"
            share_intents.share_text(
                self.driver, replayed, flags=share_intents.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY,
            )
            welcome = WelcomeBackPage(self.driver)
            welcome.app_lifecycle.activate_app_with_ui_ready(activation_timeout=15.0)
            assert welcome.is_welcome_back_screen_displayed(timeout=30), "No login screen after the relaunch"
            assert welcome.perform_login(self.device.user.password), "Login failed"
            dismiss_backup_modal(page, timeout=10)
            assert not page.is_open(timeout=PARKED_SHARE_TIMEOUT), "The replayed share opened again"

        async with self.step("A new share still opens and sends"):
            page = self.open_picker_with_text(fresh)
            await self.send_to(page, self.dm_chat_id)
            await self.await_on_peer(fresh)

    @pytest.mark.spec("SC-SHARE-18")
    async def test_send_reaches_one_chat_and_five_chats(self, share_groups) -> None:
        """One Send delivers the share to every ticked chat, one or five."""
        async with self.step("Send to one chat"):
            text = _unique("to-one")
            page = self.open_picker_with_text(text)
            await self.send_to(page, self.dm_chat_id)
            await self.await_on_peer(text)

        async with self.step("Send to five chats"):
            text = _unique("to-five")
            targets = [self.dm_chat_id] + [chat_id for chat_id, _ in share_groups[:4]]
            page = self.open_picker_with_text(text)
            await self.send_to(page, *targets)
            await self.await_in_chats(targets, text)

    @pytest.mark.spec("SC-SHARE-19")
    async def test_sent_text_shows_in_the_chat_soon_after_send(self) -> None:
        """After Send the text is on screen in the open chat within ECHO_TIMEOUT,
        counted from the tap. The count includes Appium's own lookups, and the
        tree does not show a message's sending state, so this bounds the time
        rather than proving the text was shown before the network confirmed it."""
        text = _unique("echo")
        page = self.open_picker_with_text(text)
        sent_at = await self.send_to(page, self.dm_chat_id)

        async with self.step(f"The text is on screen within {ECHO_TIMEOUT}s of Send"):
            remaining = max(1, math.ceil(ECHO_TIMEOUT - (time.monotonic() - sent_at)))
            assert ChatPage(self.driver).message_visible(text, timeout=remaining), (
                f"{text!r} was not on screen in the chat {ECHO_TIMEOUT}s after Send"
            )
            shown_after = time.monotonic() - sent_at
            assert shown_after <= ECHO_TIMEOUT, f"{text!r} took {shown_after:.1f}s to show after Send"

        async with self.step("The peer gets it"):
            await self.await_on_peer(text)
            self.logger.info("Shared text shown %.1fs after Send", shown_after)

    @pytest.mark.spec("SC-SHARE-26")
    @pytest.mark.xfail(
        reason="#22838: in portrait, Send selects the landing chat but leaves the chat list in front",
        strict=False,
    )
    async def test_send_lands_in_the_highest_selected_chat(self, share_groups) -> None:
        """Chats rank by the user's own latest send, so a fresh message in the
        1:1 puts it above every group; ticking a group first must not matter."""
        async with self.step("Put the 1:1 at the top of the list, then leave it"):
            await self.send_from_phone(_unique("rank"))
            self.leave_the_chat()

        text = _unique("landing")
        group_id, group_name = share_groups[0]
        async with self.step("Tick a group, then the 1:1, and send"):
            page = self.open_picker_with_text(text)
            await self.send_to(page, group_id, self.dm_chat_id)

        async with self.step("The open chat is the 1:1"):
            assert ChatPage(self.driver).wait_for_message_input(timeout=15), "Send opened no chat"
            self.assert_open_chat_is_the_1to1(f" (the group is {group_name!r})")
            await self.await_in_chats([group_id, self.dm_chat_id], text)

    @pytest.mark.spec("SC-SHARE-25")
    async def test_cancel_sends_nothing_and_leaves_the_sharing_app_in_front(self) -> None:
        """Cancel closes the share screen, returns to the app that shared, and sends nothing."""
        text = _unique("cancelled")
        self.driver.press_keycode(HOME_KEY)
        in_front = self.driver.current_package
        page = self.open_picker_with_text(text)
        await self.tick(page, self.dm_chat_id)

        async with self.step("Cancel"):
            page.tap_cancel()
            assert page.wait_closed(timeout=15), "The share screen stayed open after Cancel"
            assert self.wait_for_app_state(RUNNING_IN_BACKGROUND), "Status stayed in front after Cancel"
            assert self.driver.current_package == in_front, (
                f"{self.driver.current_package} is in front, not {in_front}, which was before the share"
            )

        async with self.step("A later message arrives and the cancelled text never does"):
            self.driver.activate_app(self.package)
            await self.send_from_phone(_unique("after-cancel"))
            assert self.peer.find_message(self.phone_key, text) is None, f"{text!r} reached the peer"

    @pytest.mark.spec("SC-SHARE-10")
    async def test_a_sixth_chat_cannot_be_selected(self, share_groups) -> None:
        """With five chats ticked the sixth takes no tick until one is cleared."""
        chats = [self.dm_chat_id] + [chat_id for chat_id, _ in share_groups]
        page = self.open_picker_with_text(_unique("six"))

        async with self.step("Tick five chats"):
            for chat_id in chats[:5]:
                await self.tick(page, chat_id)

        sixth = chats[5]
        async with self.step("The sixth cannot be ticked"):
            assert page.wait_for_destination(sixth, timeout=self.CROSS_DEVICE_TIMEOUT), "The sixth chat is not listed"
            assert page.wait_for_selectable(sixth, False), "The sixth row still accepts a tick"
            page.select(sixth)
            assert not page.wait_for_selected(sixth, True, timeout=3), "A sixth chat got a tick"
            assert page.is_selected(sixth) is False, "The sixth row is gone after the tap"

        async with self.step("Untick one and the sixth becomes available"):
            page.select(chats[4])
            assert page.wait_for_selected(chats[4], False), "The fifth tick did not clear"
            assert page.wait_for_selectable(sixth, True), "The sixth row stayed disabled"
            self.leave_picker(page)

    @pytest.mark.spec("SC-SHARE-23")
    async def test_send_stays_disabled_until_a_chat_is_selected(self) -> None:
        """Send is disabled with no chat ticked, enabled with one, disabled again when cleared."""
        page = self.open_picker_with_text(_unique("gate"))

        async with self.step("Nothing ticked: Send is disabled"):
            assert page.wait_for_destination(self.dm_chat_id, timeout=self.UI_TIMEOUT)
            assert page.wait_for_send_enabled(False, timeout=5), "Send is enabled with nothing ticked"

        async with self.step("Tick: Send is enabled; untick: disabled again"):
            await self.tick(page, self.dm_chat_id)
            assert page.wait_for_send_enabled(True), "Send stayed disabled after a tick"
            page.select(self.dm_chat_id)
            assert page.wait_for_selected(self.dm_chat_id, False), "The tick did not clear"
            assert page.wait_for_send_enabled(False), "Send stayed enabled with nothing ticked"
            self.leave_picker(page)
