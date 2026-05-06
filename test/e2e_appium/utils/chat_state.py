"""State recovery helpers for the function-scoped ``chat_ready`` fixture.

Lets the session-scoped ``established_chat`` fixture stay expensive but
order-agnostic: tests that close or clear the chat don't poison the next
test, since recovery via the contacts list re-opens the missing row.
"""

from config.logging_config import get_logger
from core.device_context import DeviceContext
from pages.app import App
from pages.messaging.chat_page import ChatPage
from pages.settings.settings_page import SettingsPage

logger = get_logger("chat_state")


def ensure_chat_visible(
    device: DeviceContext,
    peer_suffix: str,
    peer_display_name: str | None = None,
) -> None:
    """Guarantee the chat with ``peer_suffix`` is open on ``device``.

    Tries (cheap → expensive): already-in-chat, Messages-tab nav,
    open-from-chat-list-by-suffix, then Settings → Contacts → open-chat.
    Raises ``RuntimeError`` with a diagnostic if all paths fail.
    """
    driver = device.driver
    app = App(driver)
    chat_page = ChatPage(driver)

    if chat_page.wait_for_message_input(timeout=2):
        return

    chat_page.dismiss_backup_prompt(timeout=2)
    app.click_messages_button()
    chat_page.dismiss_backup_prompt(timeout=2)

    if chat_page.wait_for_message_input(timeout=3):
        return

    if chat_page.open_chat_by_suffix(
        peer_suffix, display_name=peer_display_name, timeout=15
    ) and chat_page.wait_for_message_input(timeout=10):
        return

    logger.info(
        "Chat row missing for %s — recovering via Settings → Contacts",
        peer_suffix,
    )

    if not app.click_settings_button():
        raise RuntimeError("Failed to open Settings during chat recovery")

    settings = SettingsPage(driver)
    if not settings.is_loaded(timeout=10):
        raise RuntimeError("Settings page did not load during chat recovery")

    # Reach Contacts via Messaging — the direct CONTACTS_MENU_ITEM locator
    # (tid:2-MenuItem) is brittle (sparse menu indices vary by build), but the
    # Messaging → Contacts path is what establish_contact uses successfully.
    messaging = settings.open_messaging_settings()
    if not messaging:
        raise RuntimeError("Failed to open messaging settings during chat recovery")

    contacts = messaging.open_contacts()
    if not contacts:
        raise RuntimeError("Failed to open contacts during chat recovery")

    # ContactPanel.content-desc on an accepted contact carries the chat-key
    # (``zQ3...{suffix}``), not the human display name — open_chat_with is
    # named for display_name but does a substring match. Pass the suffix.
    if not contacts.open_chat_with(peer_suffix):
        raise RuntimeError(
            f"Failed to open chat with contact suffix '{peer_suffix}' from contacts list"
        )

    if not chat_page.wait_for_message_input(timeout=15):
        raise RuntimeError(
            "Chat opened from contacts but message input not visible"
        )
