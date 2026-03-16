"""Shared contact establishment utilities.

Provides reusable functions for extracting chat keys/suffixes from profile
links and establishing contacts between two devices. Used by both module-scoped
fixtures (messaging/conftest, community/conftest) and inline test helpers.
"""

from __future__ import annotations

import asyncio

from config.logging_config import get_logger
from core.device_context import DeviceContext
from pages.app import App
from pages.messaging.chat_page import ChatPage
from pages.settings.settings_page import SettingsPage

logger = get_logger("contact_helpers")


def extract_chat_key(link: str) -> str:
    """Extract the full chat key from a profile link (part after ``#``)."""
    return link.rsplit("#", 1)[-1] if "#" in link else link


def extract_chat_suffix(link: str, length: int = 6) -> str:
    """Extract last *length* characters of the chat key for display."""
    return extract_chat_key(link)[-length:]


async def establish_contact(
    sender: DeviceContext,
    receiver: DeviceContext,
    *,
    timeout: int = 180,
) -> tuple[str, str, str, str]:
    """Establish a 1:1 contact between *sender* and *receiver*.

    Captures profile links, sends a contact request from *sender*,
    accepts it on *receiver*, and exchanges a setup message so that both
    devices have the chat visible.

    Returns:
        ``(sender_suffix, receiver_suffix, sender_chat_key, receiver_chat_key)``
    """
    # Capture profile links — capture_profile_link() already calls
    # activate_app() internally when the settings fallback is used.
    sender_link = await asyncio.to_thread(sender.capture_profile_link)
    receiver_link = await asyncio.to_thread(receiver.capture_profile_link)

    assert sender_link, "Sender device did not return a profile link"
    assert receiver_link, "Receiver device did not return a profile link"

    sender_suffix = extract_chat_suffix(sender_link)
    receiver_suffix = extract_chat_suffix(receiver_link)
    sender_chat_key = extract_chat_key(sender_link)
    receiver_chat_key = extract_chat_key(receiver_link)

    logger.info("Establishing contact: %s -> %s", sender_suffix, receiver_suffix)

    # Sender sends contact request
    sender_app = App(sender.driver)
    sender_settings = SettingsPage(sender.driver)

    assert sender_app.click_settings_button(), "Sender failed to open settings"
    assert sender_settings.is_loaded(timeout=12), "Sender settings page did not load"

    messaging_page = sender_settings.open_messaging_settings()
    assert messaging_page is not None, "Sender failed to open messaging settings"

    contacts_page = messaging_page.open_contacts()
    assert contacts_page is not None, "Sender failed to open contacts"

    modal = contacts_page.open_send_contact_request_modal()
    assert modal is not None, "Sender failed to open send contact request modal"

    request_message = f"Setup: {sender_suffix} connecting with {receiver_suffix}"

    assert modal.enter_chat_key(receiver_chat_key), "Sender failed to enter chat key"
    assert modal.enter_message(request_message), "Sender failed to enter message"
    assert modal.send(), "Sender failed to send contact request"

    # Navigate sender back to messages
    assert sender_app.click_messages_button(), "Sender failed to navigate to messages"
    sender_chat = ChatPage(sender.driver)
    sender_chat.dismiss_backup_prompt(timeout=4)

    # Receiver accepts contact request
    receiver_app = App(receiver.driver)
    receiver_settings = SettingsPage(receiver.driver)

    assert receiver_app.click_settings_button(), "Receiver failed to open settings"
    assert receiver_settings.is_loaded(timeout=12), "Receiver settings did not load"

    receiver_messaging = receiver_settings.open_messaging_settings()
    assert receiver_messaging is not None, "Receiver failed to open messaging settings"

    receiver_contacts = receiver_messaging.open_contacts()
    assert receiver_contacts is not None, "Receiver failed to open contacts"

    assert receiver_contacts.wait_for_pending_requests_focusable(timeout=timeout), (
        f"Receiver pending requests not available after {timeout}s"
    )
    assert receiver_contacts.open_pending_requests_tab(timeout=12), (
        "Receiver failed to open pending requests tab"
    )
    assert receiver_contacts.pending_request_row_exists(sender_suffix, timeout=12), (
        f"Pending request from '{sender_suffix}' not visible on receiver"
    )
    assert receiver_contacts.accept_contact_request(sender_suffix), (
        "Receiver failed to accept contact request"
    )

    # Navigate receiver to messages
    assert receiver_app.click_messages_button(), "Receiver failed to navigate to messages"
    receiver_chat = ChatPage(receiver.driver)
    receiver_chat.dismiss_backup_prompt(timeout=4)

    sender_display = sender.user.display_name if sender.user else None
    receiver_display = receiver.user.display_name if receiver.user else None

    # Wait for chat on receiver side and send a message to trigger it on sender side
    assert receiver_chat.wait_for_new_chat_to_arrive(
        sender_suffix, display_name=sender_display, timeout=timeout,
    ), "Chat did not arrive on receiver"

    assert receiver_chat.open_chat_by_suffix(
        sender_suffix, display_name=sender_display,
    ), "Receiver failed to open chat"

    assert receiver_chat.wait_for_message_input(timeout=15), (
        "Message input not ready on receiver"
    )

    setup_msg = f"Setup message from {receiver_suffix}"
    assert receiver_chat.send_message(setup_msg, timeout=15), (
        "Receiver failed to send setup message"
    )

    # Wait for the chat on sender side
    logger.info("Sender waiting for DM from receiver")
    assert sender_chat.wait_for_new_chat_to_arrive(
        receiver_suffix, display_name=receiver_display, timeout=timeout,
    ), "Chat did not arrive on sender"

    if not sender_chat.open_chat_by_suffix(
        receiver_suffix, display_name=receiver_display,
    ):
        logger.warning(
            "open_chat_by_suffix failed for sender; falling back to open_first_chat"
        )
        assert sender_chat.open_first_chat(timeout=15), "Sender failed to open chat"

    assert sender_chat.wait_for_message_input(timeout=15), (
        "Message input not ready on sender"
    )

    logger.info("Contact established: %s <-> %s", sender_suffix, receiver_suffix)
    return sender_suffix, receiver_suffix, sender_chat_key, receiver_chat_key
