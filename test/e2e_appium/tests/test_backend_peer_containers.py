"""Two container peers become mutual contacts on the real fleet and exchange a
1:1 message. No phone or Appium session. Needs STATUS_BACKEND_IMAGE and
STATUS_BACKEND_DOCKER_PROJECT (see scripts/peer_image.sh); skipped without them.
"""
import asyncio
import uuid

import pytest

from core import peer_containers
from core.backend_peer import onboarded, stop_all

pytestmark = [
    pytest.mark.backend_peer,
    pytest.mark.skipif(
        not peer_containers.enabled(),
        reason="STATUS_BACKEND_IMAGE is not set; nothing to start a peer container from",
    ),
]

CONTACT_TIMEOUT = 180
DELIVERY_TIMEOUT = 180


async def test_two_container_peers_exchange_a_message():
    sender = await onboarded("ContainerPeerSender")
    receiver = None
    try:
        receiver = await onboarded("ContainerPeerReceiver")

        await asyncio.to_thread(
            sender.request_contact, receiver.public_key, "Hello from the sender",
        )
        seen = await receiver.await_inbound_contact_request(timeout=CONTACT_TIMEOUT)
        assert seen == sender.public_key, (
            f"receiver saw a request from {seen} rather than the sender {sender.public_key}"
        )
        await asyncio.to_thread(receiver.accept_contact_request_from, seen)
        await sender.await_mutual_contact(receiver.public_key, timeout=CONTACT_TIMEOUT)

        text = f"container-smoke-{uuid.uuid4().hex[:8]}"
        await asyncio.to_thread(sender.send_dm, receiver.public_key, text)
        arrived = await receiver.await_chat_message(
            sender.public_key, text, timeout=DELIVERY_TIMEOUT,
        )
        assert arrived["from"] == sender.public_key
    finally:
        await stop_all(sender, receiver)
