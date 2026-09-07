"""Relay-mode status-backend as an e2e chat participant."""
from __future__ import annotations

import asyncio
import os
import threading
import time
from collections.abc import Callable

from config.logging_config import get_logger
from core import peer_containers
from core.status_go_tf import load_tf_client

logger = get_logger(__name__)

CONTAINER_START_ATTEMPTS = 3
_config_lock = threading.Lock()
_process_fleet: str | None = None


class PeerDied(RuntimeError):
    """The peer's container has gone away; carries its name and state."""


def _start_container_backend(client):
    """Retry a backend whose health check failed because the process was still
    starting; up to CONTAINER_START_ATTEMPTS."""
    for attempt in range(1, CONTAINER_START_ATTEMPTS + 1):
        try:
            return client.StatusBackend()
        except Exception as exc:
            if attempt == CONTAINER_START_ATTEMPTS:
                raise
            logger.warning("peer container attempt %s failed (%s); retrying", attempt, exc)
            time.sleep(2)


def login_identity(backend) -> dict:
    """The identity settings the login reported. When the client missed the
    login signal it rebuilds the event from RPC state with only the public key
    and mnemonic, so the rest is read from the settings service."""
    settings = dict((getattr(backend, "node_login_event", None) or {}).get("event", {}).get("settings", {}))
    service = getattr(backend, "settings_service", None)
    if not settings.get("compressedKey") and service is not None:
        settings = {**(service.get_settings() or {}), **settings}
    return settings


async def onboarded(display_name: str, fleet: str = "status.prod") -> BackendPeer:
    """A peer that is logged in and connected to the fleet. A peer whose
    onboarding fails is stopped before the error propagates, so no container
    outlives it."""
    peer = BackendPeer(fleet=fleet, display_name=display_name)
    try:
        await peer.onboard()
        assert peer.node_fleet == peer.fleet, (
            f"{display_name} joined fleet {peer.node_fleet!r}, not {peer.fleet!r}"
        )
        await peer.wait_for_peers(min_peers=1, timeout=60)
    except BaseException:
        await peer.stop()
        raise
    return peer


async def stop_all(*peers) -> list[BaseException]:
    """Stop every peer; teardown errors must not replace the test's own failure.
    Leaked containers show up in the log and in ``docker ps``."""
    results = await asyncio.gather(
        *(peer.stop() for peer in peers if peer is not None), return_exceptions=True,
    )
    failures = [result for result in results if isinstance(result, BaseException)]
    for exc in failures:
        logger.error("peer teardown failed: %r", exc)
    return failures


def _claim_process_fleet(fleet: str) -> None:
    """The client reads ``Config.waku_fleet`` at login, long after construction,
    so peers of one process cannot each have their own."""
    global _process_fleet
    if _process_fleet is not None and _process_fleet != fleet:
        raise RuntimeError(
            f"this process already runs peers on {_process_fleet!r}, not {fleet!r}; "
            "the client's Config is process-global"
        )
    _process_fleet = fleet


class BackendPeer:
    """A relay-mode status-backend acting as the non-phone chat participant."""

    def __init__(self, fleet: str = "status.prod", display_name: str = "RelayPeer"):
        self.fleet = fleet
        self.display_name = display_name
        self._sync = None
        self._identity: dict = {}

    async def onboard(self, url: str | None = None, password: str = "BackendPeer123!") -> BackendPeer:
        """Bring the peer up and log it in. Without a url the client starts a
        container instead, and owns it."""
        client = load_tf_client()

        def _sync_onboard():
            with _config_lock:
                _claim_process_fleet(self.fleet)
                if url:
                    client.Config.status_backend_urls = iter([url])
                else:
                    peer_containers.configure(client.Config)
                client.Config.waku_fleet = self.fleet
                client.Config.waku_fleets_config = ""
                client.Config.disable_override_networks = True
                be = client.StatusBackend() if url else _start_container_backend(client)
            # Held before the calls below can raise: the client starts a
            # websocket thread in its constructor, and only stop() ends it.
            self._sync = be
            be.init_status_backend()
            be.create_account_and_login(
                password=password, display_name=self.display_name, waku_light_client=False
            )
            be.wait_for_login()
            self._identity = login_identity(be)
            # Without start_messenger the waku engine never starts: no
            # subscriptions, no delivery, and the failure is silent.
            be.wakuext_service.start_messenger()
            return be

        self._sync = await asyncio.to_thread(_sync_onboard)
        assert self.chat_key.startswith("zQ3") and self.public_key.startswith("0x04"), (
            f"login reported no usable identity: {self._settings!r}"
        )
        return self

    async def stop(self) -> None:
        if self._sync is not None:
            # Releases the client's own temp datadir and stops the websocket
            # reconnect loop. Without it the loop keeps dialling the port, and
            # ports are reused, so it can latch onto the next peer.
            await asyncio.to_thread(self._sync.shutdown)
            self._sync = None

    @property
    def _settings(self) -> dict:
        if not self._identity and self._sync is not None:
            self._identity = login_identity(self._sync)
        return self._identity

    @property
    def chat_key(self) -> str:
        return self._settings.get("compressedKey", "")

    @property
    def public_key(self) -> str:
        return self._settings.get("public-key", "")

    @property
    def alias(self) -> str:
        return self._settings.get("alias", "") or ""

    @property
    def node_fleet(self) -> str:
        """Fleet as reported by the node's login event (not the constructor arg)."""
        return self._settings.get("fleet", "")

    def check_alive(self) -> None:
        self._check_liveness()

    def _check_liveness(self) -> None:
        """The client holds the only handle to the peer, so its container is
        the only place liveness can be read. A peer reached over a url has no
        container and nothing to check."""
        container = self._container()
        if container is None:
            return
        container.reload()
        if container.status != "running":
            raise PeerDied(
                f"peer container {container.name} is {container.status}, not running"
                + self._log_tail(container)
            )

    def _container(self):
        return getattr(getattr(self._sync, "container", None), "container", None)

    def _log_tail(self, container, limit: int = 4000) -> str:
        try:
            tail = container.logs(tail=200).decode("utf-8", "replace")
        except Exception as exc:
            return f"\n(container log unavailable: {exc})"
        return "\n--- peer container log tail ---\n" + tail[-limit:]

    def dump_logs(self, dest_dir: str) -> None:
        """The peer's own log, kept before the container is removed."""
        container = self._container()
        if container is None:
            return
        os.makedirs(dest_dir, exist_ok=True)
        path = os.path.join(dest_dir, f"{container.name}.log")
        try:
            with open(path, "wb") as fh:
                fh.write(container.logs())
        except Exception as exc:
            logger.warning("peer log capture failed for %s: %s", container.name, exc)

    def request_contact(self, contact_key: str, message: str = "Hello"):
        """Named apart from ``CreateChatPage.send_contact_request``, which
        reports bool success while this returns the RPC payload."""
        return self._sync.wakuext_service.send_contact_request(contact_key, message)

    def accept_contact_request_from(self, sender_public_key: str):
        return self._sync.wakuext_service.accept_latest_contact_request_for_contact(sender_public_key)

    def _sent_message_id(self, result: dict, **fields) -> str:
        messages = (result or {}).get("messages") or []
        mine = [
            m for m in messages
            if m.get("from") == self.public_key
            and all(m.get(k) == v for k, v in fields.items())
        ]
        if not mine:
            raise RuntimeError(
                f"send returned no message authored by this peer matching {fields!r}; "
                f"payload held {[(m.get('id'), m.get('text')) for m in messages]!r}"
            )
        return max(mine, key=lambda m: m.get("clock", 0))["id"]

    def send_dm(self, contact_key: str, text: str) -> str:
        """rpc_request hands back the already-unwrapped JSON-RPC result."""
        result = self._sync.wakuext_service.send_one_to_one_message(contact_key, text)
        return self._sent_message_id(result, text=text)

    def has_contact(self, public_key: str, require_mutual: bool = False) -> bool:
        """Contacts are keyed by the 0x04 legacy key, but the payload also
        carries the zQ3 compressedKey; callers may hold either form."""
        contacts = self._sync.wakuext_service.get_contacts() or []
        for c in contacts:
            if public_key not in (c.get("id"), c.get("compressedKey")):
                continue
            if not require_mutual:
                return True
            # Older payloads carry an explicit "mutual"; newer ones imply it
            # via added + hasAddedUs.
            return bool(c.get("mutual")) or (
                bool(c.get("added")) and bool(c.get("hasAddedUs"))
            )
        return False

    def pending_inbound_contact_key(self) -> str:
        """Public key of a contact who has added us but whom we have not added
        back, i.e. an unanswered inbound request. Empty string when there is
        none. Polled rather than awaited so a peer without a signal client can
        still complete a handshake."""
        for c in self._sync.wakuext_service.get_contacts() or []:
            if c.get("hasAddedUs") and not c.get("added"):
                return c.get("id") or ""
        return ""

    async def await_inbound_contact_request(self, timeout: int = 120) -> str:
        return await self._await(
            "an inbound contact request", self.pending_inbound_contact_key, timeout,
        )

    async def await_mutual_contact(self, public_key: str, timeout: int = 60) -> None:
        await self._await(
            f"contact {public_key[:12]}… mutual", lambda: self.has_contact(public_key, True), timeout,
        )

    @staticmethod
    def dm_chat_id(public_key: str) -> str:
        """status-go keys a 1:1 chat by the other party's 0x04 public key."""
        return public_key

    def chat_messages(self, contact_key: str, limit: int = 30) -> list[dict]:
        payload = self._sync.wakuext_service.chat_messages(
            self.dm_chat_id(contact_key), limit=limit,
        ) or {}
        return payload.get("messages") or []

    def chat_message_texts(self, contact_key: str, limit: int = 20) -> list[str]:
        return [m.get("text", "") for m in self.chat_messages(contact_key, limit)]

    def find_message(self, contact_key: str, text: str, limit: int = 30) -> dict | None:
        return next((m for m in self.chat_messages(contact_key, limit) if m.get("text") == text), None)

    async def await_chat_message(self, contact_key: str, text: str, timeout: int = 120) -> dict:
        try:
            return await self._await(
                f"{text!r} on the peer", lambda: self.find_message(contact_key, text), timeout,
            )
        except TimeoutError:
            texts = self.chat_message_texts(contact_key)
            raise TimeoutError(
                f"{text!r} never reached the peer within {timeout}s; "
                f"its last {len(texts)} message(s): {texts!r}"
            ) from None

    async def await_new_message_from(
        self, contact_key: str, known_ids: set[str], timeout: int = 120,
    ) -> dict:
        """The peer's copy of the next message from ``contact_key``, whatever its
        text. For sends whose text the sender chooses, like an emoji picker."""

        def probe():
            for message in self.chat_messages(contact_key):
                if message.get("id") not in known_ids and message.get("from") == contact_key:
                    return message
            return None

        return await self._await(
            f"a new message from {contact_key[:12]}…", probe, timeout,
        )

    def reactions_on(self, contact_key: str, message_id: str) -> list[dict]:
        return self._sync.wakuext_service.emoji_reactions_by_chat_id_message_id(
            self.dm_chat_id(contact_key), message_id,
        ) or []

    async def await_reaction(self, contact_key: str, message_id: str, timeout: int = 120) -> list[dict]:
        return await self._await(
            f"a reaction on {message_id}", lambda: self.reactions_on(contact_key, message_id), timeout,
        )

    def send_reply(self, contact_key: str, text: str, response_to: str) -> str:
        result = self._sync.wakuext_service.send_chat_message(
            self.dm_chat_id(contact_key), text, responseTo=response_to,
        )
        return self._sent_message_id(result, text=text, responseTo=response_to)

    def revise_message(self, message_id: str, new_text: str):
        """Edit a message the peer already sent. Named apart from the page
        objects' ``submit_message_edit`` because that reports bool success
        while this returns the RPC payload."""
        return self._sync.wakuext_service.edit_message(message_id, new_text)

    def add_reaction(self, contact_key: str, message_id: str, emoji_code: str):
        """``emoji_code`` is the unicode hex the UI keys its reaction buttons on
        ("1f600"). wakuext_sendEmojiReaction takes that string; the older
        EmojiReaction_Type enum is deprecated."""
        return self._sync.wakuext_service.send_emoji_reaction(
            self.dm_chat_id(contact_key), message_id, emoji_code,
        )

    def purge_chat_history(self, contact_key: str):
        """Clear the peer's own copy of the conversation. Named apart from
        ``ChatPage.clear_history``, which reports bool success."""
        return self._sync.wakuext_service.clear_history(self.dm_chat_id(contact_key))

    def deactivate_dm(self, contact_key: str, preserve_history: bool = True):
        """Close the chat on the peer only. Named apart from
        ``ChatPage.close_chat``, which reports bool success."""
        return self._sync.wakuext_service.deactivate_chat(
            self.dm_chat_id(contact_key), preserve_history,
        )

    def dm_is_active(self, contact_key: str) -> bool:
        chat_id = self.dm_chat_id(contact_key)
        for chat in self._sync.wakuext_service.active_chats() or []:
            if chat.get("id") == chat_id:
                return True
        return False

    def peers(self) -> dict:
        """Connected waku peers (peer-id -> protocols/addresses). Only
        available once start_messenger has run."""
        return self._sync.wakuext_service.rpc_request("peers") or {}

    async def wait_for_peers(self, min_peers: int = 1, timeout: int = 30) -> dict:
        return await self._await(
            f"{min_peers} waku peer(s)",
            lambda: (lambda p: p if len(p) >= min_peers else None)(self.peers()), timeout,
        )

    async def _await(self, describe: str, probe: Callable, timeout: int, interval: float = 2.0):
        deadline = time.monotonic() + timeout
        while True:
            self._check_liveness()
            try:
                found = await asyncio.to_thread(probe)
            except Exception:
                # A probe that fails because the peer died should say so, with
                # the peer's log, rather than surface as a bare connection error.
                self._check_liveness()
                raise
            if found:
                return found
            if time.monotonic() >= deadline:
                raise TimeoutError(f"no {describe} within {timeout}s")
            await asyncio.sleep(interval)
