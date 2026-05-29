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
from pages.onboarding.welcome_back_page import WelcomeBackPage
from pages.settings.settings_page import SettingsPage
from utils.app_lifecycle_manager import AppLifecycleManager
from utils.timeouts import CROSS_DEVICE_DELIVERY_TIMEOUT_SECONDS

logger = get_logger("contact_helpers")


def extract_chat_key(link: str) -> str:
    """Extract the full chat key from a profile link (part after ``#``)."""
    return link.rsplit("#", 1)[-1] if "#" in link else link


def extract_chat_suffix(link: str, length: int = 6) -> str:
    """Extract last *length* characters of the chat key for display."""
    return extract_chat_key(link)[-length:]


def _restart_and_login(device: DeviceContext, *, label: str) -> bool:
    """Restart *device* and re-authenticate via the WelcomeBack screen.

    Used as an explicit storenode-fetch trigger: per ``utils/timeouts.py``
    docstring, app restart forces a storenode history fetch that
    bypasses live-delivery, which is the canonical recovery path when
    waku-mediated cross-device delivery hasn't propagated yet.

    Side effect: also clears any stale drawer/QML UI state that
    accumulates over a long session, which materially reduces the rate
    of ``click_settings_button`` flakes on BrowserStack.
    """
    driver = device.driver
    password = device.user.password if device.user else None
    if not password:
        logger.error("_restart_and_login(%s): no password on user", label)
        return False

    logger.info("_restart_and_login(%s): restarting app", label)
    lifecycle = AppLifecycleManager(driver)
    if not lifecycle.restart_app():
        logger.error("_restart_and_login(%s): restart_app returned False", label)
        return False

    # Bring UI to a tappable state after the cold restart.
    try:
        lifecycle.activate_app_with_ui_ready(activation_timeout=15.0)
    except Exception as exc:
        logger.debug(
            "_restart_and_login(%s): activate_app_with_ui_ready raised: %s",
            label, exc,
        )

    welcome_back = WelcomeBackPage(driver)
    if not welcome_back.is_welcome_back_screen_displayed(timeout=30):
        # If the WelcomeBack screen isn't shown, the app may have
        # auto-logged-in (Status persists the keychain across restarts on
        # some configs). Treat as success and let the caller verify the
        # subsequent navigation.
        logger.info(
            "_restart_and_login(%s): WelcomeBack screen not visible — "
            "assuming auto-login", label,
        )
        return True

    if not welcome_back.perform_login(password, timeout=60):
        logger.error("_restart_and_login(%s): perform_login returned False", label)
        return False

    logger.info("_restart_and_login(%s): login complete", label)
    return True


async def establish_contact(
    sender: DeviceContext,
    receiver: DeviceContext,
    *,
    timeout: int = CROSS_DEVICE_DELIVERY_TIMEOUT_SECONDS,
    verify_delivery: bool = True,
    receiver_restart_before_accept: bool = False,
) -> tuple[str, str, str, str]:
    """Establish a 1:1 contact between *sender* and *receiver*.

    Captures profile links, sends a contact request from *sender*,
    accepts it on *receiver*, and exchanges a setup message so that both
    devices have the chat visible.

    ``verify_delivery`` (default True) controls the bidirectional Waku
    delivery gate at the end. Setting it False skips the
    receiver→sender and sender→receiver verification messages — the
    contacts are still established at the protocol level via the send +
    accept flow, but the caller is responsible for any later
    verification. Use False when the caller will assert delivery via a
    subsequent test step (e.g. multi-device fixture setups that already
    pay BS cost for the gate elsewhere).

    ``receiver_restart_before_accept`` (default False) inserts an app
    restart + re-login on the receiver BEFORE sender sends the
    contact request. This is empirically better than restarting AFTER
    sender sends: a post-send restart relies on storenode catch-up to
    deliver the missed request, which doesn't reliably complete within
    the 360s pending-tab wait on BrowserStack.
    A pre-send restart instead ensures the receiver's Waku filter
    subscription is freshly active when the contact request hits the
    network, so the request is delivered LIVE to the receiver — no
    storenode dependency. Also resets BS drawer/QML state so the
    subsequent Settings nav is less likely to flake. Costs ~30-60s.

    Returns:
        ``(sender_suffix, receiver_suffix, sender_chat_key, receiver_chat_key)``
    """
    # Parallel: each call drives only its own driver. Saves ~2 min on BS.
    sender_link, receiver_link = await asyncio.gather(
        asyncio.to_thread(sender.capture_profile_link),
        asyncio.to_thread(receiver.capture_profile_link),
    )

    assert sender_link, "Sender device did not return a profile link"
    assert receiver_link, "Receiver device did not return a profile link"

    sender_suffix = extract_chat_suffix(sender_link)
    receiver_suffix = extract_chat_suffix(receiver_link)
    sender_chat_key = extract_chat_key(sender_link)
    receiver_chat_key = extract_chat_key(receiver_link)

    logger.info("Establishing contact: %s -> %s", sender_suffix, receiver_suffix)

    # Optional: restart the receiver BEFORE the sender sends, so its Waku
    # filter subscription is freshly active when the request hits the
    # network and the request arrives live. The alternative (restart
    # after send, relying on storenode catch-up) doesn't reliably deliver
    # within the 360s pending-tab wait.
    if receiver_restart_before_accept:
        assert _restart_and_login(receiver, label=receiver_suffix), (
            "Receiver restart-and-login failed"
        )
        # Dismiss the post-login overlays — backup prompt, push-notif
        # popup (Android 13+), and drawer-intro dialog — that otherwise
        # eat the subsequent Settings nav click.
        post_restart_chat = ChatPage(receiver.driver)
        post_restart_chat.dismiss_backup_prompt(timeout=4)
        post_restart_chat.dismiss_backup_prompt(timeout=2)
        post_restart_chat.dismiss_push_notification_prompt(timeout=4)
        post_restart_chat.dismiss_drawer_intro_prompt(timeout=2)
        # Let the Waku filter subscription settle before sender publishes.
        await asyncio.sleep(10)

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
    sender_chat = ChatPage(sender.driver)
    sender_chat.dismiss_backup_prompt(timeout=4)
    assert sender_app.click_messages_button(), "Sender failed to navigate to messages"
    sender_chat.dismiss_backup_prompt(timeout=2)

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

    # Let Waku filter subscription propagate before messaging.
    await asyncio.sleep(5)

    # Navigate receiver to messages
    receiver_chat = ChatPage(receiver.driver)
    receiver_chat.dismiss_backup_prompt(timeout=4)
    assert receiver_app.click_messages_button(), "Receiver failed to navigate to messages"
    receiver_chat.dismiss_backup_prompt(timeout=2)

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

    # Wait for the chat on sender side — re-tap Messages to refresh the
    # list in case the P2P message arrived but the UI hasn't updated.
    logger.info("Sender waiting for DM from receiver")
    sender_chat.dismiss_backup_prompt(timeout=2)
    assert sender_app.click_messages_button(), "Sender failed to refresh messages tab"
    sender_chat.dismiss_backup_prompt(timeout=2)
    sender_chat.dismiss_introduce_prompt(timeout=2)

    assert sender_chat.wait_for_new_chat_to_arrive(
        receiver_suffix, display_name=receiver_display, timeout=timeout,
    ), "Chat did not arrive on sender"

    assert sender_chat.open_chat_by_suffix(
        receiver_suffix, display_name=receiver_display,
    ), "Sender failed to open chat"

    assert sender_chat.wait_for_message_input(timeout=15), (
        "Message input not ready on sender"
    )

    # Delivery gate — bidirectional (status-go#7393).
    # The Waku filter subscription race means messages sent immediately after
    # contact acceptance can be dropped in either direction.  Verify both
    # directions before yielding so tests don't run against a half-working session.
    if verify_delivery:
        # Direction 1: receiver → sender (setup message already sent above)
        assert sender_chat.message_exists(setup_msg, timeout=CROSS_DEVICE_DELIVERY_TIMEOUT_SECONDS), (
            "Delivery gate failed: setup message from receiver not visible on sender. "
            "Waku filter subscription may not have propagated yet."
        )

        # Direction 2: sender → receiver
        ping_msg = f"Ping from {sender_suffix}"
        assert sender_chat.send_message(ping_msg, timeout=15), (
            "Delivery gate failed: sender could not send ping message"
        )
        assert receiver_chat.message_exists(ping_msg, timeout=CROSS_DEVICE_DELIVERY_TIMEOUT_SECONDS), (
            "Delivery gate failed: ping from sender not visible on receiver. "
            "Waku filter subscription may not have propagated yet."
        )
    else:
        logger.info(
            "Delivery gate skipped (verify_delivery=False) — caller "
            "must assert delivery downstream"
        )

    logger.info("Contact established: %s <-> %s", sender_suffix, receiver_suffix)
    return sender_suffix, receiver_suffix, sender_chat_key, receiver_chat_key


async def establish_contacts_admin_to_many(
    admin: DeviceContext,
    receivers: list[DeviceContext],
    *,
    timeout: int = CROSS_DEVICE_DELIVERY_TIMEOUT_SECONDS,
    receiver_restart_before_accept: bool = True,
) -> list[tuple[str, str, str, str]]:
    """Establish admin↔receiver contacts with receiver-side work overlapped.

    Drop-in replacement for sequentially calling
    :func:`establish_contact` once per receiver, when one admin is
    pairing with multiple receivers (typical: 3-device group chat
    setup). The win comes from overlapping the slow waku-delivery
    waits across receivers — admin sends both requests serially
    (because admin's UI can only navigate one place at a time), then
    BOTH receivers accept in parallel, then BOTH receivers send their
    setup messages in parallel.

    With two receivers the overlap roughly halves contact-exchange wall
    time (the ~6-min worst-case ``pending_request_row_exists`` waku wait
    runs once instead of per receiver).

    ``verify_delivery`` is not exposed — the bidirectional gate doesn't
    compose across multiple receivers without doubling admin nav cost,
    and the fixture verifies delivery downstream anyway.

    Default path for 2+ receivers in the messaging conftest; set
    ``USE_PARALLEL_CONTACT_EXCHANGE=0`` to force the sequential 1:1 path.

    Returns a list of ``(admin_suffix, receiver_suffix,
    admin_chat_key, receiver_chat_key)`` tuples in the same order as
    *receivers*.
    """
    if not receivers:
        return []
    if len(receivers) == 1:  # nothing to overlap; use the 1:1 path
        result = await establish_contact(
            admin, receivers[0], timeout=timeout,
            verify_delivery=False,
            receiver_restart_before_accept=receiver_restart_before_accept,
        )
        return [result]

    if receiver_restart_before_accept:
        labels = [f"recv-{i}" for i in range(len(receivers))]
        restart_results = await asyncio.gather(
            *[
                asyncio.to_thread(_restart_and_login, r, label=labels[i])
                for i, r in enumerate(receivers)
            ]
        )
        assert all(restart_results), (
            f"Receiver restart-and-login failed: {restart_results}"
        )

        def _dismiss_overlays(receiver: DeviceContext) -> None:
            chat = ChatPage(receiver.driver)
            chat.dismiss_backup_prompt(timeout=4)
            chat.dismiss_backup_prompt(timeout=2)
            chat.dismiss_push_notification_prompt(timeout=4)
            chat.dismiss_drawer_intro_prompt(timeout=2)

        await asyncio.gather(
            *[asyncio.to_thread(_dismiss_overlays, r) for r in receivers]
        )
        await asyncio.sleep(10)  # let filter subscriptions settle

    captures = await asyncio.gather(
        asyncio.to_thread(admin.capture_profile_link),
        *[asyncio.to_thread(r.capture_profile_link) for r in receivers],
    )
    admin_link = captures[0]
    receiver_links = captures[1:]
    assert admin_link, "Admin did not return a profile link"
    for i, link in enumerate(receiver_links):
        assert link, f"Receiver {i} did not return a profile link"

    admin_suffix = extract_chat_suffix(admin_link)
    admin_chat_key = extract_chat_key(admin_link)
    receiver_suffixes = [extract_chat_suffix(link) for link in receiver_links]
    receiver_chat_keys = [extract_chat_key(link) for link in receiver_links]

    # Phase C: admin sends a contact request to each receiver. Navigate
    # Settings → Messaging → Contacts ONCE, then reopen the send-request
    # modal per receiver from the contacts page (send() closes the modal
    # back to it). Re-walking Settings per receiver instead leaves the
    # settings nav in a state where open_messaging_settings fails on the
    # second receiver.
    sender_app = App(admin.driver)
    sender_settings = SettingsPage(admin.driver)
    sender_chat = ChatPage(admin.driver)

    assert sender_app.click_settings_button(), "Admin Settings click failed"
    assert sender_settings.is_loaded(timeout=12), (
        "Admin settings page did not load"
    )
    messaging_page = sender_settings.open_messaging_settings()
    assert messaging_page is not None, "Admin failed to open messaging settings"
    contacts_page = messaging_page.open_contacts()
    assert contacts_page is not None, "Admin failed to open contacts"

    for i, (rcv_chat_key, rcv_suffix) in enumerate(
        zip(receiver_chat_keys, receiver_suffixes)
    ):
        logger.info(
            "Admin sending contact request %d/%d: %s -> %s",
            i + 1, len(receivers), admin_suffix, rcv_suffix,
        )
        assert contacts_page.is_loaded(timeout=12), (
            f"Contacts page not in view before sending to {rcv_suffix}"
        )
        modal = contacts_page.open_send_contact_request_modal()
        assert modal is not None, (
            f"Admin failed to open send modal for {rcv_suffix}"
        )

        request_message = (
            f"Setup: {admin_suffix} connecting with {rcv_suffix}"
        )
        assert modal.enter_chat_key(rcv_chat_key), (
            f"Admin enter_chat_key failed for {rcv_suffix}"
        )
        assert modal.enter_message(request_message), (
            f"Admin enter_message failed for {rcv_suffix}"
        )
        assert modal.send(), (
            f"Admin send failed for {rcv_suffix}"
        )

    sender_chat.dismiss_backup_prompt(timeout=4)
    assert sender_app.click_messages_button(), (
        "Admin failed to navigate back to messages after sending requests"
    )
    sender_chat.dismiss_backup_prompt(timeout=2)

    # Phase D: receivers accept in parallel threads, so the slow
    # pending-request waku wait overlaps instead of stacking.
    def _accept_on_receiver(receiver: DeviceContext, rcv_suffix: str) -> bool:
        rec_app = App(receiver.driver)
        rec_settings = SettingsPage(receiver.driver)
        assert rec_app.click_settings_button(), (
            f"Receiver {rcv_suffix} failed to open settings"
        )
        assert rec_settings.is_loaded(timeout=12), (
            f"Receiver {rcv_suffix} settings did not load"
        )
        rec_messaging = rec_settings.open_messaging_settings()
        assert rec_messaging is not None, (
            f"Receiver {rcv_suffix} failed to open messaging settings"
        )
        rec_contacts = rec_messaging.open_contacts()
        assert rec_contacts is not None, (
            f"Receiver {rcv_suffix} failed to open contacts"
        )
        assert rec_contacts.wait_for_pending_requests_focusable(timeout=timeout), (
            f"Receiver {rcv_suffix} pending requests not available "
            f"after {timeout}s"
        )
        assert rec_contacts.open_pending_requests_tab(timeout=12), (
            f"Receiver {rcv_suffix} failed to open pending requests tab"
        )
        assert rec_contacts.pending_request_row_exists(admin_suffix, timeout=12), (
            f"Pending request from admin not visible on {rcv_suffix}"
        )
        assert rec_contacts.accept_contact_request(admin_suffix), (
            f"Receiver {rcv_suffix} failed to accept contact request"
        )
        return True

    await asyncio.gather(*[
        asyncio.to_thread(_accept_on_receiver, r, receiver_suffixes[i])
        for i, r in enumerate(receivers)
    ])

    await asyncio.sleep(5)  # let filter subscriptions settle post-accept

    # Phase E: each receiver sends a setup message so its chat row appears
    # on the admin side (verifies the contact is live, in parallel).
    def _setup_message_from_receiver(
        receiver: DeviceContext, rcv_suffix: str,
    ) -> str:
        rec_app = App(receiver.driver)
        rec_chat = ChatPage(receiver.driver)
        rec_chat.dismiss_backup_prompt(timeout=4)
        assert rec_app.click_messages_button(), (
            f"Receiver {rcv_suffix} failed to navigate to messages"
        )
        rec_chat.dismiss_backup_prompt(timeout=2)

        assert rec_chat.wait_for_new_chat_to_arrive(
            admin_suffix, display_name=None, timeout=timeout,
        ), f"Chat from admin did not arrive on {rcv_suffix}"
        assert rec_chat.open_chat_by_suffix(
            admin_suffix, display_name=None,
        ), f"Receiver {rcv_suffix} failed to open chat with admin"
        assert rec_chat.wait_for_message_input(timeout=15), (
            f"Message input not ready on {rcv_suffix}"
        )
        setup_msg = f"Setup message from {rcv_suffix}"
        assert rec_chat.send_message(setup_msg, timeout=15), (
            f"Receiver {rcv_suffix} failed to send setup message"
        )
        return setup_msg

    await asyncio.gather(*[
        asyncio.to_thread(_setup_message_from_receiver, r, receiver_suffixes[i])
        for i, r in enumerate(receivers)
    ])

    # Phase F: admin refreshes messages and waits for each receiver's
    # chat row (fast — the messages already arrived during Phase E).
    sender_chat.dismiss_backup_prompt(timeout=2)
    assert sender_app.click_messages_button(), (
        "Admin failed to refresh messages tab after receiver accepts"
    )
    sender_chat.dismiss_backup_prompt(timeout=2)
    sender_chat.dismiss_introduce_prompt(timeout=2)

    for rcv_suffix in receiver_suffixes:
        assert sender_chat.wait_for_new_chat_to_arrive(
            rcv_suffix, display_name=None, timeout=timeout,
        ), f"Admin never saw chat from {rcv_suffix}"

    logger.info(
        "Contacts established admin↔[%s]",
        ", ".join(receiver_suffixes),
    )
    return [
        (admin_suffix, rs, admin_chat_key, rk)
        for rs, rk in zip(receiver_suffixes, receiver_chat_keys)
    ]
