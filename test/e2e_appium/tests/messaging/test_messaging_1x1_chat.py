import asyncio
from typing import Optional, Tuple

import pytest

from pages.messaging.chat_page import ChatPage
from pages.app import App
from pages.settings.messaging_page import MessagingSettingsPage
from pages.settings.settings_page import SettingsPage
from pages.settings.contacts_page import ContactsSettingsPage
from utils.multi_device_helpers import StepMixin


class TestMessaging1x1Chat(StepMixin):

    DM_TIMEOUT = 120
    UI_TIMEOUT = 12

    @pytest.mark.messaging
    @pytest.mark.smoke
    @pytest.mark.device_count(2)
    async def test_contact_request_flow(self) -> None:
        primary_device = self.device
        secondary_device = self.get_device(1)

        primary_link, secondary_link = await self._capture_profile_links(
            primary_device, secondary_device
        )
        primary_suffix = self._extract_chat_suffix(primary_link)
        secondary_suffix = self._extract_chat_suffix(secondary_link)

        contact_request_message = await self._primary_sends_request(
            primary_device,
            recipient_link=secondary_link,
            primary_suffix=primary_suffix,
            secondary_suffix=secondary_suffix,
        )
        await self._secondary_accepts_request(secondary_device, primary_suffix)

        await self._exchange_messages(
            primary_device,
            secondary_device,
            primary_suffix=primary_suffix,
            secondary_suffix=secondary_suffix,
            contact_request_message=contact_request_message,
        )

        await asyncio.gather(
            self._verify_contact_listing(
                primary_device,
                contact_suffix=secondary_suffix,
                log_label="Primary contact verification",
            ),
            self._verify_contact_listing(
                secondary_device,
                contact_suffix=primary_suffix,
                log_label="Secondary contact verification",
            ),
        )

    async def _capture_profile_links(
        self,
        primary_device,
        secondary_device,
    ) -> Tuple[str, str]:
        async def _capture(device, label: str) -> str:
            async with self.step(device, label):
                link = await asyncio.to_thread(device.capture_profile_link)
                assert link, f"{device.device_id} did not return a profile link"
                assert device.user is not None, f"{device.device_id} has no onboarded user"
                assert getattr(device.user, "profile_link", None) == link, (
                    f"Profile link not stored on {device.device_id} user state"
                )
                return link.strip()

        return await asyncio.gather(
            _capture(primary_device, "Capture profile link from primary user"),
            _capture(secondary_device, "Capture profile link from secondary user"),
        )

    @staticmethod
    def _extract_chat_key(link: str) -> str:
        """Extract full chat key from profile link (part after #)."""
        return link.rsplit("#", 1)[-1] if "#" in link else link

    @staticmethod
    def _extract_chat_suffix(link: str, length: int = 6) -> str:
        """Extract last N characters of chat key for display."""
        chat_key = link.rsplit("#", 1)[-1] if "#" in link else link
        return chat_key[-length:]

    async def _primary_sends_request(
        self,
        device,
        *,
        recipient_link: str,
        primary_suffix: str,
        secondary_suffix: str,
    ) -> str:
        main_app = App(device.driver)
        settings_page = SettingsPage(device.driver)

        async with self.step(device, "Open settings from primary user"):
            assert main_app.click_settings_button(), "Failed to open settings"
            assert settings_page.is_loaded(timeout=self.UI_TIMEOUT), "Settings page did not load"

        async with self.step(device, "Navigate to messaging settings"):
            messaging_page = settings_page.open_messaging_settings()
            assert messaging_page is not None, "Failed to open messaging settings"

        async with self.step(device, "Open contacts settings"):
            contacts_page = messaging_page.open_contacts()
            assert contacts_page is not None, "Failed to open contacts settings"

        async with self.step(device, "Open send contact request modal"):
            modal = contacts_page.open_send_contact_request_modal()
            assert modal is not None, "Failed to open send contact request modal"

        request_message = f"Hi {secondary_suffix}, it's {primary_suffix}. Let's connect on Status!"
        async with self.step(device, "Send contact request to secondary user"):
            chat_key = self._extract_chat_key(recipient_link)
            assert modal.enter_chat_key(chat_key), "Failed to enter chat key"
            assert modal.enter_message(request_message), "Failed to enter message"
            assert modal.send(), "Failed to send contact request"

        async with self.step(device, "Navigate back to messages"):
            assert main_app.click_messages_button(), "Failed to navigate to messages"
            chat_page = ChatPage(device.driver)
            chat_page.dismiss_backup_prompt(timeout=4)  # Dismiss if visible
            assert chat_page.is_loaded(timeout=self.UI_TIMEOUT), "Chat page did not load"

        return request_message

    async def _secondary_accepts_request(self, device, primary_suffix: str) -> None:
        main_app = App(device.driver)
        settings_page = SettingsPage(device.driver)
        messaging_page: Optional[MessagingSettingsPage] = None

        async with self.step(device, "Open settings from secondary user"):
            assert main_app.click_settings_button(), "Failed to open settings from navigation"
            assert settings_page.is_loaded(timeout=self.UI_TIMEOUT), (
                "Settings page did not load on secondary device"
            )

        async with self.step(device, "Navigate to messaging settings"):
            messaging_page = settings_page.open_messaging_settings()
            assert isinstance(
                messaging_page, MessagingSettingsPage
            ), "Failed to open messaging settings on secondary device"
        assert messaging_page is not None

        async with self.step(device, "Open contacts settings list"):
            contacts_page = messaging_page.open_contacts()
            assert contacts_page is not None, "Failed to open contacts settings list"

        async with self.step(device, "Wait for pending request to arrive"):
            assert contacts_page.wait_for_pending_requests_focusable(
                timeout=self.DM_TIMEOUT
            ), (
                f"Pending requests tab not clickable after {self.DM_TIMEOUT}s - "
                "contact request may not have been delivered"
            )

        async with self.step(device, "Open pending requests tab and accept"):
            assert contacts_page.open_pending_requests_tab(timeout=self.UI_TIMEOUT), (
                "Failed to open pending requests tab"
            )
            assert contacts_page.pending_request_row_exists(
                primary_suffix,
                timeout=self.UI_TIMEOUT,
            ), f"Pending request from '{primary_suffix}' not visible in list"
            assert contacts_page.accept_contact_request(primary_suffix), (
                "Failed to accept contact request"
            )

    async def _exchange_messages(
        self,
        primary_device,
        secondary_device,
        *,
        primary_suffix: str,
        secondary_suffix: str,
        contact_request_message: str,
    ) -> None:
        assert primary_device.user is not None, f"{primary_device.device_id} has no onboarded user"
        assert secondary_device.user is not None, f"{secondary_device.device_id} has no onboarded user"
        primary_display_name = primary_device.user.display_name
        secondary_display_name = secondary_device.user.display_name

        secondary_chat_page = ChatPage(secondary_device.driver)
        primary_chat_page = ChatPage(primary_device.driver)

        async with self.step(secondary_device, "Dismiss backup prompt if visible"):
            secondary_chat_page.dismiss_backup_prompt(timeout=4)

        async with self.step(secondary_device, "Verify contact request message received"):
            assert secondary_chat_page.wait_for_new_chat_to_arrive(
                primary_suffix,
                display_name=primary_display_name,
            ), (
                "Secondary did not show DM row for the primary contact"
            )
            assert secondary_chat_page.message_exists(
                contact_request_message,
                timeout=self.UI_TIMEOUT,
            ), "Contact request message not visible on secondary"

        async with self.step(secondary_device, "Send greeting to primary"):
            assert secondary_chat_page.wait_for_message_input(timeout=self.UI_TIMEOUT), (
                "Secondary message composer did not appear"
            )
            assert secondary_chat_page.send_message(
                "Hello from secondary",
                timeout=self.UI_TIMEOUT,
            ), "Secondary failed to send initial DM"

        async with self.step(primary_device, "Wait for DM from secondary"):
            assert primary_chat_page.wait_for_new_chat_to_arrive(
                secondary_suffix,
                display_name=secondary_display_name,
                timeout=self.DM_TIMEOUT,
            ), "Primary did not receive DM from secondary within timeout"

        async with self.step(primary_device, "Open messaging thread from primary side"):
            assert primary_chat_page.open_chat_by_suffix(
                secondary_suffix,
                display_name=secondary_display_name,
            ), (
                "Primary did not open the DM row for secondary"
            )
            assert primary_chat_page.wait_for_message_input(timeout=self.UI_TIMEOUT), (
                "Primary message composer did not appear"
            )
            assert primary_chat_page.message_exists(
                "Hello from secondary",
                timeout=self.DM_TIMEOUT,
            ), "Primary did not receive secondary's greeting"

        async with self.step(primary_device, "Reply to secondary"):
            assert primary_chat_page.send_message(
                "Reply from primary",
                timeout=self.UI_TIMEOUT,
            ), "Primary failed to send DM reply"

        async with self.step(secondary_device, "Wait for reply from primary"):
            assert secondary_chat_page.wait_for_new_chat_to_arrive(
                primary_suffix,
                display_name=primary_display_name,
                timeout=self.DM_TIMEOUT,
            ), "Secondary did not receive reply from primary within timeout"

        async with self.step(secondary_device, "Confirm reply received"):
            assert secondary_chat_page.open_chat_by_suffix(
                primary_suffix,
                display_name=primary_display_name,
            ), (
                "Secondary could not focus the DM row after primary's reply"
            )
            assert secondary_chat_page.wait_for_message_input(timeout=self.UI_TIMEOUT), (
                "Secondary message composer did not reappear after refocusing"
            )
            assert secondary_chat_page.message_exists(
                "Reply from primary",
                timeout=self.DM_TIMEOUT,
            ), "Secondary did not receive primary's reply"

    async def _verify_contact_listing(
        self,
        device,
        *,
        contact_suffix: str,
        log_label: str,
    ) -> None:
        main_app = App(device.driver)
        settings_page = SettingsPage(device.driver)
        messaging_page: Optional[MessagingSettingsPage] = None

        async with self.step(device, f"{log_label}: open settings navigation"):
            max_attempts = 3
            for attempt in range(max_attempts):
                if main_app.click_settings_button() and settings_page.is_loaded(timeout=8):
                    break
            else:
                raise AssertionError("Settings page did not open after retries")

        async with self.step(device, f"{log_label}: open messaging settings"):
            messaging_page = settings_page.open_messaging_settings()
            assert messaging_page is not None, "Failed to open messaging settings"
        assert messaging_page is not None

        async with self.step(device, f"{log_label}: open contacts tab"):
            contacts_page = messaging_page.open_contacts()
            assert contacts_page is not None, "Failed to open contacts settings list"
            assert contacts_page.open_contacts_tab(timeout=self.UI_TIMEOUT), (
                "Failed to open contacts tab"
            )
            assert contacts_page.contacts_row_exists(
                contact_suffix,
                timeout=self.UI_TIMEOUT,
            ), "Contacts list did not include the expected user"
