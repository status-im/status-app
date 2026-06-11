"""Destination-identity helpers for the nav arrival check (#21086).

Background: the portrait nav returns success on "drawer closed", which a missed
tap also satisfies -- so a broken nav passes green (the masked-failure class).
``confirm_screen`` checks a SCREEN-UNIQUE accessibility anchor instead. On this
Qt build the a11y tree is reliable for *identity* (it correctly reflects which
screen is shown -- a live dump on the backup modal exposed that modal's own
test-ids and none of the screen anchors); its weakness is *timing* lag, which a
generous post-settle timeout absorbs. So presence-of-anchor answers "am I on the
intended screen?" -- rejecting a wrong destination (e.g. an interrupting modal)
and accepting an already-there no-op, both of which a "changed-from-source"
pixel check gets wrong.

``dismiss_backup_modal`` clears the on-device-backup popup, which intermittently
intercepts the Messaging nav and then blocks the nav drawer entirely -- the
concrete cause of the nav wedges seen while building this.
"""

from locators.base_locators import BaseLocators
from locators.wallet.accounts_locators import WalletAccountsLocators
from locators.settings.settings_locators import SettingsLocators
from locators.messaging.chat_locators import ChatLocators

# Screen-unique landing anchor per screen. Presence == "on this screen".
# Messages uses the new-chat header button, not the headline: a live a11y dump
# on the Messages screen showed CHAT_HEADER's tid is stale (never resolves) while
# startChatButton is present whether or not the chat list has conversations.
SCREEN_ANCHORS = {
    "wallet": WalletAccountsLocators().ADD_ACCOUNT_BUTTON,
    "settings": SettingsLocators().PROFILE_MENU_ITEM,
    "messages": ChatLocators().START_CHAT_BUTTON,
}

BACKUP_MODAL = BaseLocators.tid("EnableMessageBackupPopup")
BACKUP_MODAL_SKIP = BaseLocators.tid("backupMessageSkipStatusFlatButton")


def dismiss_backup_modal(page, timeout: int = 2) -> bool:
    """Tap Skip on the on-device-backup popup if it is up. Returns True if a
    modal was dismissed. Safe to call before or after any navigation.

    Never raises: callers use this as a guard inside nav retry loops, so a
    failed dismissal must fall through to the caller's own retry, not abort
    it (safe_click raises on exhaustion)."""
    if not page.is_element_visible(BACKUP_MODAL, timeout=timeout):
        return False
    try:
        page.safe_click(BACKUP_MODAL_SKIP, timeout=5)
        return page.wait_for_invisibility(BACKUP_MODAL, timeout=5)
    except Exception as exc:
        page.logger.warning("Backup modal present but dismissal failed: %s", exc)
        return False


def confirm_screen(page, expected: str, timeout: int = 15) -> bool:
    """Identity gate: is ``expected`` screen actually shown? Polls that screen's
    unique a11y anchor with a lag-tolerant timeout. Raises KeyError for an
    unknown screen name so a typo fails loudly instead of silently passing."""
    return page.is_element_visible(SCREEN_ANCHORS[expected], timeout=timeout)
