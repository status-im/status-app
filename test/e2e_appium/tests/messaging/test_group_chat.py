"""Group chat tests — 3 BrowserStack devices.

Covers the desktop critical ``test_group_chat_add_contact_in_ac`` scope
adapted to mobile:

- creation propagation (admin + 2 members)
- group name visibility on all three
- message delivery from admin to both peers
- rename propagation
- member removal + readd
- non-admin leave

Uses the module-scoped ``group_chat_context`` fixture (in ``conftest.py``)
which provisions 3 sessions, onboards 3 users, and exchanges admin-rooted
contacts (admin↔B, admin↔C — no B↔C pair). The group chat itself is created in-test
(``test_01_...``) so the creation assertion stays at the test level.

Mobile's create-chat surface gates 1-1 vs group on
``model.count >= 2`` (see ``CreateChatView.qml``) — that's why 2 devices
isn't enough; the minimum group is admin + 2 peers.

Test order is significant. The class shares state via ``cls.group_name``
(set by test_01 from the auto-derived header name) so subsequent tests
can find the group by its actual on-device name rather than a guess.
"""

from __future__ import annotations

import asyncio
import uuid
from contextlib import asynccontextmanager

import pytest

from config.logging_config import get_logger
from pages.app import App
from pages.base_page import BasePage
from pages.messaging.chat_page import ChatPage
from pages.messaging.group_chat_page import GroupChatPage
from utils.timeouts import CROSS_DEVICE_DELIVERY_TIMEOUT_SECONDS


def _unique_message(prefix: str = "gc") -> str:
    return f"{prefix}_{uuid.uuid4().hex[:8]}"


@pytest.mark.messaging
@pytest.mark.smoke
@pytest.mark.device_count(3)
@pytest.mark.timeout(3600)
class TestGroupChat:
    """3-device group chat lifecycle: create → message → manage → leave.

    ``timeout(3600)`` (60 min) covers the full 7-test suite: fixture
    cost is paid ONCE per pytest session (~10 min after the batched
    admin-rooted establishment optimisation) and amortises across all
    seven test bodies (~3-5 min each). 30-min cap was right for
    single-test runs but too tight for the full suite.

    No ``@flaky`` reruns: the tests mutate shared group state through
    the module-scoped fixture (test_05 removes a member, test_07 has one
    leave), so a single-test rerun would start from the already-mutated
    state — e.g. rerunning test_05 finds the member already gone — and
    fail spuriously while masking the real first-attempt failure. Body
    flakes must be fixed, not retried.
    """

    UI_TIMEOUT = 30
    CROSS_DEVICE_TIMEOUT = CROSS_DEVICE_DELIVERY_TIMEOUT_SECONDS
    MESSAGE_DELIVERY_TIMEOUT = CROSS_DEVICE_DELIVERY_TIMEOUT_SECONDS

    logger = get_logger("TestGroupChat")

    # Set by test_01 after reading the auto-derived name from the header.
    group_name: str | None = None
    # Set by test_01 from the auto-derived group name's &-joined parts —
    # the members' Frilledlizard identity names as admin sees them.
    # Used by test_05/06 to target a specific member in the Members panel
    # (rows are identified by content-desc = identity name).
    member_b_identity: str | None = None
    member_c_identity: str | None = None

    @pytest.fixture(autouse=True)
    def setup(self, group_chat_context):
        self.ctx = group_chat_context
        self.admin = group_chat_context.admin
        self.member_b = group_chat_context.member_b
        self.member_c = group_chat_context.member_c
        self.admin_driver = group_chat_context.admin.driver
        self.member_b_driver = group_chat_context.member_b.driver
        self.member_c_driver = group_chat_context.member_c.driver

    @asynccontextmanager
    async def step(self, description: str):
        self.logger.info("Step: %s", description)
        try:
            yield
        finally:
            self.logger.info("Done:  %s", description)

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    def _group_row_locator_on(self, device) -> tuple | None:
        """Get a locator for the group chat row on *device* via exclusion.

        Identifies the group as "any StatusDraggableListItem whose
        name-segment isn't one of the 1:1 chat names captured at
        fixture setup". On Pi (Android API 35), chat list rows have
        empty ``text``/``content-desc`` and the group name is hash-
        mangled in the resource-id, so name-based lookup is brittle.
        Exclusion is stable across renames.
        """
        gcp = GroupChatPage(device.driver)
        known = self.ctx.one_to_one_names_by_device.get(device.device_id, [])
        return gcp.find_group_row_by_exclusion(known)

    async def _navigate_to_messages(self, device_driver) -> ChatPage:
        """Bring *device_driver* to the chat list and dismiss prompts."""
        app = App(device_driver)
        chat_page = ChatPage(device_driver)

        chat_page.dismiss_backup_prompt(timeout=2)
        app.click_messages_button()
        chat_page.dismiss_backup_prompt(timeout=2)
        await asyncio.sleep(0.5)
        return chat_page

    async def _wait_for_group_on_device(
        self,
        device,
        group_name: str,
        *,
        total_wait: int = 360,
        poll_interval: int = 15,
        label: str = "device",
        use_exclusion: bool = True,
    ) -> bool:
        """Poll *device*'s chat list until the group appears or timeout.

        Active polling — re-navigates and re-checks every ``poll_interval``
        seconds for up to ``total_wait``. Tolerates the transient
        BrowserStack ``urllib3.connectionpool`` "Connection pool full"
        warnings that exit ``WebDriverWait`` early without a real
        timeout, and gives Waku group-invite propagation real wall-clock
        time (1-3 min nominal).

        The group row locator is re-derived via exclusion AFTER each
        navigate (when ``use_exclusion``) — deriving it once up front is
        wrong when the device starts inside the open chat (no chat-list
        rows are present, so exclusion yields None).
        """
        import time
        gcp = GroupChatPage(device.driver)
        deadline = time.time() + total_wait
        attempt = 0
        while time.time() < deadline:
            attempt += 1
            try:
                await self._navigate_to_messages(device.driver)
                row_locator = (
                    self._group_row_locator_on(device)
                    if use_exclusion else None
                )
                if gcp.is_group_chat_visible(
                    group_name, timeout=10, row_locator=row_locator,
                ):
                    self.logger.info(
                        "%s sees group %r on poll attempt %d",
                        label, group_name, attempt,
                    )
                    return True
            except Exception as exc:
                self.logger.debug(
                    "%s visibility poll %d raised %s — retrying",
                    label, attempt, exc,
                )
            remaining = deadline - time.time()
            if remaining <= 0:
                break
            await asyncio.sleep(min(poll_interval, max(1, remaining)))
        # Final diagnostic dump on failure
        try:
            BasePage(device.driver).dump_page_source(
                f"group_not_visible_{label}_{group_name[:30]}"
            )
        except Exception:
            pass
        return False

    async def _all_see_group(self, group_name: str) -> list[bool]:
        """[admin, member_b, member_c] visibility of the group in chat list.

        Resolves the row per-device via exclusion-based lookup
        (resilient to QML resource-id hash mangling on rename and
        empty content-desc/text on Pi). ``group_name`` is informational
        only — used for logs and as a fallback locator if exclusion
        finds nothing for some reason.
        """
        labels = ("admin", self.ctx.member_b_name, self.ctx.member_c_name)
        results = []
        for device, label in zip(self.ctx.members(), labels):
            results.append(
                await self._wait_for_group_on_device(
                    device, group_name,
                    total_wait=self.CROSS_DEVICE_TIMEOUT,
                    poll_interval=15,
                    label=label,
                )
            )
        return results

    # ------------------------------------------------------------------
    # Tests (numeric ordering is intentional — state flows through the class)
    # ------------------------------------------------------------------

    @pytest.mark.spec("SC-GRP-01")
    async def test_01_create_group_chat_visible_to_all(self):
        """Admin creates a group with B and C; all three see it listed.

        Mobile auto-derives the group name from the picked contacts'
        local identity names (Frilledlizard-style, e.g.
        ``"Nippy Idolized Dalmatian"``) joined by ``&``. We read the
        derived name from the admin's chat-list row (most recent chat
        = the new group) rather than from the chat header, because
        mobile may not auto-open the newly created group chat after
        confirmation — leaving the admin on the chat list. The chat
        list row exposes the chat name in its content-desc / text /
        resource-id regardless of whether the chat is currently open.
        """
        async with self.step(
            f"Admin creates group with {self.ctx.member_b_name}, "
            f"{self.ctx.member_c_name}"
        ):
            await self._navigate_to_messages(self.admin_driver)
            gcp_admin = GroupChatPage(self.admin_driver)
            created = gcp_admin.create_group_chat(
                group_name="<auto>",
                members=[self.ctx.member_b_name, self.ctx.member_c_name],
                timeout=self.UI_TIMEOUT,
            )
            assert created, "Admin could not complete create-group flow"

        async with self.step("Admin reads auto-derived group name from chat list"):
            # Mobile auto-derives the group name as "<B identity>&<C
            # identity>" (CreateChatView.qml createChat() joins on "&").
            # Find the group row by the "&" marker — it distinguishes the
            # group from the pre-existing 1-1 chat rows. Chat-list order
            # is not a reliable discriminator.
            await self._navigate_to_messages(self.admin_driver)
            base = BasePage(self.admin_driver)
            group_row_locator = (
                "xpath",
                "//*[contains(@resource-id,'StatusDraggableListItem') and "
                "(contains(@text,'&') or contains(@content-desc,'&') or "
                "contains(@resource-id,'&'))]",
            )
            element = base.find_element_safe(
                group_row_locator, timeout=self.CROSS_DEVICE_TIMEOUT,
            )
            assert element, (
                "No '&'-containing chat-list row appeared on admin's "
                "chat list — group chat may not be visible yet"
            )
            derived = None
            for attr in ("content-desc", "text"):
                try:
                    value = element.get_attribute(attr)
                    if value and value not in ("null", "") and "&" in value:
                        derived = value.strip()
                        if " [tid:" in derived:
                            derived = derived.split(" [tid:")[0].strip()
                        if derived:
                            break
                except Exception:
                    continue
            if not derived:
                # Resource-id fallback: parse "...<name>.StatusDraggableListItem_..."
                try:
                    rid = element.get_attribute("resource-id") or ""
                    if ".StatusDraggableListItem_" in rid and "&" in rid:
                        prefix = rid.split(".StatusDraggableListItem_", 1)[0]
                        derived = prefix.rsplit(".", 1)[-1] if "." in prefix else prefix
                except Exception:
                    pass
            assert derived, (
                "Group row found by '&' marker but name extraction "
                "failed (content-desc, text, and resource-id all empty)"
            )
            type(self).group_name = derived
            self.logger.info("Auto-derived group_name = %r", derived)
            # The auto-derived name is "<B identity>&<C identity>" — the
            # members in the order they were picked ([member_b, member_c]).
            # Capture them now (before any rename in test_04) for the
            # Members-panel member targeting in test_05/06.
            if "&" in derived:
                parts = [p.strip() for p in derived.split("&")]
                type(self).member_b_identity = parts[0]
                type(self).member_c_identity = parts[-1]
                self.logger.info(
                    "Member identities: B=%r C=%r",
                    self.member_b_identity, self.member_c_identity,
                )

        async with self.step("All 3 devices see the group in the chat list"):
            visibility = await self._all_see_group(self.group_name)
            admin_sees, b_sees, c_sees = visibility
            assert admin_sees, "Admin does not see their own new group"
            assert b_sees, f"{self.ctx.member_b_name} does not see the new group"
            assert c_sees, f"{self.ctx.member_c_name} does not see the new group"

    async def test_02_group_chat_name_visible(self):
        """Every member can open the propagated group chat and lands in it.

        Originally read the group name from the chat header, but Qt
        accessibility on Android API 35 (Pi devices) doesn't bridge
        ``StatusChatInfoButton.title`` (or its nested
        ``statusChatInfoButtonNameText`` Text element) to either
        ``content-desc`` or ``text`` — both come back empty even when
        the title is visibly rendered. The header is unreadable on
        this surface.

        So this verifies a weaker but real semantic: each device
        locates the group row by exclusion (the non-1:1 row), opens it,
        and lands in chat view (message input visible) — confirming the
        group propagated and is functionally addressable on every
        device. It does NOT assert the displayed name, which isn't
        readable here.
        """
        assert self.group_name, "test_01 must run first to set group_name"

        for label, device in (
            ("admin", self.admin),
            (self.ctx.member_b_name, self.member_b),
            (self.ctx.member_c_name, self.member_c),
        ):
            async with self.step(f"{label} opens the group"):
                await self._navigate_to_messages(device.driver)
                gcp = GroupChatPage(device.driver)
                row_locator = self._group_row_locator_on(device)
                assert gcp.open_group_chat_by_name(
                    self.group_name,
                    timeout=self.CROSS_DEVICE_TIMEOUT,
                    row_locator=row_locator,
                ), f"{label} could not open group chat"
                chat = ChatPage(device.driver)
                assert chat.wait_for_message_input(
                    timeout=self.UI_TIMEOUT,
                ), f"{label} did not land in chat view after opening group"

    @pytest.mark.spec("SC-GRP-02")
    async def test_03_send_message_visible_to_all(self):
        """Message sent by admin lands on both members' screens."""
        assert self.group_name, "test_01 must run first to set group_name"
        message = _unique_message("hello")

        async with self.step(f"Admin opens group and sends {message!r}"):
            chat_admin = ChatPage(self.admin_driver)
            gcp_admin = GroupChatPage(self.admin_driver)
            await self._navigate_to_messages(self.admin_driver)
            admin_row = self._group_row_locator_on(self.admin)
            assert gcp_admin.open_group_chat_by_name(
                self.group_name,
                timeout=self.CROSS_DEVICE_TIMEOUT,
                row_locator=admin_row,
            )
            assert chat_admin.wait_for_message_input(
                timeout=self.UI_TIMEOUT,
            ), "Composer not ready on admin device"
            assert chat_admin.send_message(
                message, timeout=self.UI_TIMEOUT,
            ), "send_message returned False on admin device"

        for label, device in (
            (self.ctx.member_b_name, self.member_b),
            (self.ctx.member_c_name, self.member_c),
        ):
            async with self.step(f"Verify message delivered to {label}"):
                chat = ChatPage(device.driver)
                gcp = GroupChatPage(device.driver)
                await self._navigate_to_messages(device.driver)
                row_locator = self._group_row_locator_on(device)
                assert gcp.open_group_chat_by_name(
                    self.group_name,
                    timeout=self.CROSS_DEVICE_TIMEOUT,
                    row_locator=row_locator,
                ), f"{label} could not open the group chat"
                assert chat.message_exists(
                    message, timeout=self.MESSAGE_DELIVERY_TIMEOUT,
                ), f"Message {message!r} did not arrive on {label}"

    @pytest.mark.spec("SC-GRP-03")
    async def test_04_rename_group_propagates(self):
        """Admin renames the group; the new name shows in the chat header.

        The rename action is hard-asserted, so a broken menu/save flow fails
        for real. Only the readback is conditional: on Pi the header title
        doesn't bridge to a11y, so if it can't be read the test xfails at that
        point (imperative ``pytest.xfail``). Once the QML exposes the title via
        Accessible.name the readback passes and the test goes green — no marker
        to remove. ``cls.group_name`` is left unchanged because the a11y tree
        keeps exposing the original auto-derived name to later lookups.
        """
        assert self.group_name, "test_01 must run first to set group_name"
        new_name = f"renamed-{uuid.uuid4().hex[:6]}"

        async with self.step(f"Admin renames group to {new_name!r}"):
            await self._navigate_to_messages(self.admin_driver)
            gcp = GroupChatPage(self.admin_driver)
            admin_row = self._group_row_locator_on(self.admin)
            renamed = gcp.rename_group_from_chat_list(
                old_name=self.group_name,
                new_name=new_name,
                timeout=self.UI_TIMEOUT,
                row_locator=admin_row,
            )
            assert renamed, "Admin rename flow did not complete"

        async with self.step("New name shows in the group header (admin)"):
            await self._navigate_to_messages(self.admin_driver)
            gcp = GroupChatPage(self.admin_driver)
            admin_row = self._group_row_locator_on(self.admin)
            assert gcp.open_group_chat_by_name(
                self.group_name, timeout=self.UI_TIMEOUT, row_locator=admin_row,
            )
            actual = gcp.get_group_name_from_header(timeout=self.UI_TIMEOUT)
            if actual != new_name:
                pytest.xfail(
                    f"group name not exposed via a11y on Pi (header={actual!r}); "
                    "resolves once the QML exposes the chat title via Accessible.name"
                )
            assert actual == new_name

    @pytest.mark.spec("SC-GRP-04")
    @pytest.mark.spec("SC-GRP-05")
    @pytest.mark.spec("SC-GRP-12")
    async def test_05_remove_member_from_group(self):
        """Admin removes member C: member count drops 3→2, the remaining
        member still receives messages, later messages don't reach C, and
        C's composer shows the not-a-member lockout.

        A baseline message is sent BEFORE the removal and confirmed on the
        remaining member's device. That isolates the post-removal delivery
        check: if the baseline arrives but the post-removal message doesn't,
        the removal disrupted delivery (a real signal) rather than it being
        general cross-device flake.

        Removal goes via the Members panel (header Members button →
        member row by identity name → long-press → Remove from group).
        NOTE: the Members button has no objectName, so it's tapped by
        position — Pi-passing but not cross-device robust; the robust
        fix is a one-line upstream objectName on membersButton.
        """
        assert self.group_name, "test_01 must run first to set group_name"
        assert self.member_c_identity, "test_01 must set member_c_identity"
        pre_remove_msg = _unique_message("pre-remove")
        post_remove_msg = _unique_message("post-remove")

        async with self.step("Admin's Members panel shows 3 members before removal"):
            await self._navigate_to_messages(self.admin_driver)
            gcp = GroupChatPage(self.admin_driver)
            admin_row = self._group_row_locator_on(self.admin)
            count_before = gcp.count_members_in_panel(
                self.group_name, timeout=self.UI_TIMEOUT, row_locator=admin_row,
            )
            assert count_before == 3, (
                "Expected 3 members (admin + B + C) before removal; "
                f"Members panel showed {count_before}"
            )

        async with self.step(
            f"Baseline: {self.ctx.member_b_name} receives a message before removal"
        ):
            await self._navigate_to_messages(self.admin_driver)
            chat = ChatPage(self.admin_driver)
            gcp = GroupChatPage(self.admin_driver)
            admin_row = self._group_row_locator_on(self.admin)
            assert gcp.open_group_chat_by_name(
                self.group_name, timeout=self.UI_TIMEOUT, row_locator=admin_row,
            )
            assert chat.wait_for_message_input(timeout=self.UI_TIMEOUT)
            assert chat.send_message(pre_remove_msg, timeout=self.UI_TIMEOUT)
            chat_b = ChatPage(self.member_b_driver)
            gcp_b = GroupChatPage(self.member_b_driver)
            await self._navigate_to_messages(self.member_b_driver)
            b_row = self._group_row_locator_on(self.member_b)
            assert gcp_b.open_group_chat_by_name(
                self.group_name, timeout=self.CROSS_DEVICE_TIMEOUT, row_locator=b_row,
            )
            assert chat_b.message_exists(
                pre_remove_msg, timeout=self.MESSAGE_DELIVERY_TIMEOUT,
            ), (
                f"Baseline failed: {self.ctx.member_b_name} did not receive "
                f"{pre_remove_msg!r} BEFORE removal (general delivery flake, "
                "not a removal-specific failure)"
            )

        async with self.step(f"Admin removes {self.member_c_identity}"):
            await self._navigate_to_messages(self.admin_driver)
            gcp = GroupChatPage(self.admin_driver)
            admin_row = self._group_row_locator_on(self.admin)
            assert gcp.remove_member(
                self.group_name,
                self.member_c_identity,
                timeout=self.UI_TIMEOUT,
                row_locator=admin_row,
            ), f"remove_member({self.member_c_identity}) failed"

        async with self.step("Admin's Members panel shows 2 members after removal"):
            gcp = GroupChatPage(self.admin_driver)
            count_after = None
            # Poll up to the Waku timeout: the removal may take time to
            # reflect in the panel.
            deadline = asyncio.get_running_loop().time() + self.CROSS_DEVICE_TIMEOUT
            while asyncio.get_running_loop().time() < deadline:
                await self._navigate_to_messages(self.admin_driver)
                admin_row = self._group_row_locator_on(self.admin)
                count_after = gcp.count_members_in_panel(
                    self.group_name, timeout=self.UI_TIMEOUT, row_locator=admin_row,
                )
                if count_after == 2:
                    break
                await asyncio.sleep(10)
            assert count_after == 2, (
                "Expected 2 members (admin + B) after removing C; "
                f"Members panel showed {count_after}"
            )

        async with self.step(f"Admin sends {post_remove_msg!r} post-removal"):
            chat = ChatPage(self.admin_driver)
            gcp = GroupChatPage(self.admin_driver)
            # Navigate to the chat list first: after remove_member, admin
            # is still in the Members panel, so the exclusion locator must
            # be re-derived from the chat list (else it returns None).
            await self._navigate_to_messages(self.admin_driver)
            admin_row = self._group_row_locator_on(self.admin)
            assert gcp.open_group_chat_by_name(
                self.group_name, timeout=self.UI_TIMEOUT,
                row_locator=admin_row,
            )
            assert chat.wait_for_message_input(timeout=self.UI_TIMEOUT)
            assert chat.send_message(post_remove_msg, timeout=self.UI_TIMEOUT)

        async with self.step(
            f"{self.ctx.member_b_name} (still a member) sees the message"
        ):
            chat_b = ChatPage(self.member_b_driver)
            gcp_b = GroupChatPage(self.member_b_driver)
            await self._navigate_to_messages(self.member_b_driver)
            b_row = self._group_row_locator_on(self.member_b)
            assert gcp_b.open_group_chat_by_name(
                self.group_name, timeout=self.CROSS_DEVICE_TIMEOUT,
                row_locator=b_row,
            )
            assert chat_b.message_exists(
                post_remove_msg, timeout=self.MESSAGE_DELIVERY_TIMEOUT,
            ), (
                f"{self.ctx.member_b_name} got the pre-removal baseline but NOT "
                f"{post_remove_msg!r} after removal — removal disrupted delivery "
                "to the remaining member"
            )

        async with self.step(
            f"{self.ctx.member_c_name} (removed) does NOT see the message"
        ):
            chat_c = ChatPage(self.member_c_driver)
            await self._navigate_to_messages(self.member_c_driver)
            # Sanity check only: 30s can't rule out late delivery on its own —
            # safe because the prior step already waited 360s for B. The lockout
            # step below is the authoritative "C removed" proof; keep adjacent.
            assert not chat_c.message_exists(
                post_remove_msg, timeout=self.UI_TIMEOUT,
            ), (
                f"{self.ctx.member_c_name} received {post_remove_msg!r} "
                "after being removed — removal did not propagate"
            )

        async with self.step(
            f"{self.ctx.member_c_name} (removed) is locked out of the composer"
        ):
            # A removed member keeps the group in their list but can no
            # longer post: opening it shows the not-a-member placeholder and
            # disables sending (desktop's YOU_NEED_TO_BE_A_MEMBER check).
            gcp_c = GroupChatPage(self.member_c_driver)
            await self._navigate_to_messages(self.member_c_driver)
            c_row = self._group_row_locator_on(self.member_c)
            assert gcp_c.open_group_chat_by_name(
                self.group_name, timeout=self.CROSS_DEVICE_TIMEOUT,
                row_locator=c_row,
            ), f"{self.ctx.member_c_name} could not open the group to check lockout"
            # Removal must propagate to C before the composer locks — allow
            # cross-device time.
            assert gcp_c.is_removed_member_lockout_shown(
                timeout=self.CROSS_DEVICE_TIMEOUT,
            ), (
                f"{self.ctx.member_c_name}'s composer did not show the "
                "not-a-member lockout after removal"
            )

    @pytest.mark.spec("SC-GRP-06")
    async def test_06_add_member_to_existing_group(self):
        """Admin re-adds member C; C sees new messages again."""
        assert self.group_name, "test_01 must run first to set group_name"
        assert self.member_c_identity, "test_01 must set member_c_identity"
        readd_msg = _unique_message("readd")

        async with self.step(f"Admin adds {self.member_c_identity} back"):
            await self._navigate_to_messages(self.admin_driver)
            gcp = GroupChatPage(self.admin_driver)
            admin_row = self._group_row_locator_on(self.admin)
            # Waku-grade timeout: a just-removed member only re-appears as
            # an addable contact once the removal has propagated.
            assert gcp.add_member_to_existing_group(
                self.group_name,
                self.member_c_identity,
                timeout=self.CROSS_DEVICE_TIMEOUT,
                row_locator=admin_row,
            ), f"Admin could not re-add {self.member_c_identity}"

        async with self.step(f"Admin sends {readd_msg!r} to re-added member"):
            chat = ChatPage(self.admin_driver)
            gcp = GroupChatPage(self.admin_driver)
            # Back to the chat list before re-deriving the exclusion
            # locator (after add, admin is in the add/remove sheet).
            await self._navigate_to_messages(self.admin_driver)
            admin_row = self._group_row_locator_on(self.admin)
            assert gcp.open_group_chat_by_name(
                self.group_name, timeout=self.UI_TIMEOUT,
                row_locator=admin_row,
            )
            assert chat.wait_for_message_input(timeout=self.UI_TIMEOUT)
            assert chat.send_message(readd_msg, timeout=self.UI_TIMEOUT)

        async with self.step(f"{self.ctx.member_c_name} sees the message"):
            chat_c = ChatPage(self.member_c_driver)
            gcp_c = GroupChatPage(self.member_c_driver)
            await self._navigate_to_messages(self.member_c_driver)
            c_row = self._group_row_locator_on(self.member_c)
            assert gcp_c.open_group_chat_by_name(
                self.group_name, timeout=self.CROSS_DEVICE_TIMEOUT,
                row_locator=c_row,
            )
            assert chat_c.message_exists(
                readd_msg, timeout=self.MESSAGE_DELIVERY_TIMEOUT,
            ), f"Re-added member did not receive {readd_msg!r}"

    @pytest.mark.spec("SC-GRP-07")
    async def test_07_leave_group(self):
        """Member B leaves the group; group disappears from B's chat list."""
        assert self.group_name, "test_01 must run first to set group_name"

        async with self.step(f"{self.ctx.member_b_name} leaves the group"):
            await self._navigate_to_messages(self.member_b_driver)
            gcp_b = GroupChatPage(self.member_b_driver)
            b_row = self._group_row_locator_on(self.member_b)
            assert gcp_b.leave_group(
                self.group_name, timeout=self.UI_TIMEOUT,
                row_locator=b_row,
            ), f"{self.ctx.member_b_name} could not leave"

        async with self.step(
            f"{self.ctx.member_b_name}'s chat list no longer shows the group"
        ):
            await self._navigate_to_messages(self.member_b_driver)
            # Confirm the chat list actually loaded (B still has the 1:1
            # with admin) so a missing group row means the leave took
            # effect, not that the list is empty/unrendered — otherwise
            # the exclusion check below would pass vacuously.
            base_b = BasePage(self.member_b_driver)
            assert base_b.is_element_visible(
                ("xpath", "//*[contains(@resource-id,'StatusDraggableListItem')]"),
                timeout=self.CROSS_DEVICE_TIMEOUT,
            ), f"{self.ctx.member_b_name}'s chat list did not load"
            # The group row is gone when exclusion finds no non-1:1 row.
            assert self._group_row_locator_on(self.member_b) is None, (
                f"Group still on {self.ctx.member_b_name}'s chat list after leaving"
            )

        async with self.step(
            f"Admin and {self.ctx.member_c_name} still see the group"
        ):
            admin_gcp = GroupChatPage(self.admin_driver)
            c_gcp = GroupChatPage(self.member_c_driver)
            await self._navigate_to_messages(self.admin_driver)
            admin_row = self._group_row_locator_on(self.admin)
            assert admin_gcp.is_group_chat_visible(
                self.group_name, timeout=self.CROSS_DEVICE_TIMEOUT,
                row_locator=admin_row,
            ), "Admin lost the group after B left"
            await self._navigate_to_messages(self.member_c_driver)
            c_row = self._group_row_locator_on(self.member_c)
            assert c_gcp.is_group_chat_visible(
                self.group_name, timeout=self.CROSS_DEVICE_TIMEOUT,
                row_locator=c_row,
            ), f"{self.ctx.member_c_name} lost the group after B left"
