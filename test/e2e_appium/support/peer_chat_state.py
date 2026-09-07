"""State recovery for the function-scoped ``peer_chat_ready`` fixture."""

import time

from selenium.common.exceptions import InvalidSessionIdException

from config.logging_config import get_logger
from core.device_context import DeviceContext
from pages.app import App
from pages.messaging.chat_page import ChatPage
from support.screen_identity import dismiss_introduce_yourself

logger = get_logger("peer_chat_state")

DEEP_LINK_ATTEMPTS = 3


def open_peer_chat_by_deeplink(device: DeviceContext, peer, attempts: int = DEEP_LINK_ATTEMPTS) -> bool:
    """Open the peer's 1:1 through the status-app:// deep link."""
    driver = device.driver
    chat_page = ChatPage(driver)
    package = driver.capabilities.get("appPackage") or "app.status.mobile"
    for attempt in range(1, attempts + 1):
        try:
            driver.execute_script(
                "mobile: deepLink",
                {"url": f"status-app://p/{peer.public_key}", "package": package},
            )
        except InvalidSessionIdException:
            raise
        except Exception as exc:
            logger.warning("deepLink attempt %d failed: %s", attempt, exc)
        chat_page.dismiss_backup_prompt(timeout=4)
        if dismiss_introduce_yourself(chat_page, timeout=1):
            logger.info("Dismissed introduce-yourself sheet after deep link")
        if chat_page.wait_for_message_input(timeout=10):
            return True
        logger.warning("Peer chat not open after deep link attempt %d", attempt)
        chat_page.dump_page_source(f"peer_chat_deeplink_a{attempt}")
    return False


def _settles(predicate, timeout: float, interval: float = 1.0) -> bool:
    deadline = time.monotonic() + timeout
    while True:
        if predicate():
            return True
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return False
        time.sleep(min(interval, remaining))


def peer_chat_row_listed(device: DeviceContext, peer) -> bool:
    """Whether a row named for the peer is listed right now."""
    wanted = [v for v in (peer.display_name, peer.alias, peer.chat_key[-4:]) if v]
    names = ChatPage(device.driver).listed_chat_names()
    return any(any(w in n for w in wanted) for n in names)


def peer_chat_row_visible(device: DeviceContext, peer, timeout: int = 45) -> bool:
    return _settles(lambda: peer_chat_row_listed(device, peer), timeout)


def wait_for_peer_chat_row_gone(device: DeviceContext, peer, timeout: int = 10) -> bool:
    """Absence counts only on the list screen, and only once it has held for a
    second read: an empty snapshot is also what a different screen, a list
    still populating and a driver error return."""
    chat_page = ChatPage(device.driver)

    def _gone() -> bool:
        return chat_page._is_chat_list_visible(timeout=1) and not peer_chat_row_listed(device, peer)

    if not _settles(_gone, timeout):
        return False
    time.sleep(1)
    return _gone()


def ensure_peer_chat_visible(device: DeviceContext, peer) -> ChatPage:
    """Guarantee the peer's 1:1 is open with the composer visible."""
    chat_page = ChatPage(device.driver)
    if chat_page.wait_for_message_input(timeout=2):
        return _composer_ready(chat_page)

    app = App(device.driver)
    chat_page.dismiss_backup_prompt(timeout=2)
    if not app.click_messages_button():
        logger.warning("Messages tab did not report a click; falling through to the deep link")
    chat_page.dismiss_backup_prompt(timeout=2)
    if chat_page.wait_for_message_input(timeout=3):
        return _composer_ready(chat_page)

    if open_peer_chat_by_deeplink(device, peer):
        return _composer_ready(chat_page)

    raise RuntimeError(
        "Could not open the backend peer's chat: neither the Messages tab nor "
        f"the status-app://p/{peer.public_key[:12]}… deep link reached a composer"
    )


def _composer_ready(chat_page: ChatPage) -> ChatPage:
    """Clear Reply or Edit left on by a failed test before sending."""
    if not chat_page.cancel_reply(timeout=2):
        raise RuntimeError("a reply mode left on by the previous test could not be cancelled")
    if not chat_page.cancel_edit(timeout=2):
        raise RuntimeError("an edit mode left on by the previous test could not be cancelled")
    return chat_page
