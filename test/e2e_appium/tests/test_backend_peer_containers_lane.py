"""Five peer containers alive at once on one docker network, what a messaging
gate at -n 5 asks of the agent. Started from one test so xdist scheduling
cannot hide a collision. Same requirements as test_backend_peer_containers.py.
"""
import asyncio

import pytest

from core import peer_containers
from core.backend_peer import BackendPeer, onboarded, stop_all

pytestmark = [
    pytest.mark.backend_peer,
    pytest.mark.skipif(
        not peer_containers.enabled(),
        reason="STATUS_BACKEND_IMAGE is not set; nothing to start a peer container from",
    ),
]

SLOTS = 5


async def test_five_peer_containers_run_side_by_side():
    results = await asyncio.gather(
        *(onboarded(f"ContainerPeerSlot{slot}") for slot in range(SLOTS)),
        return_exceptions=True,
    )
    peers = [r for r in results if isinstance(r, BackendPeer)]
    body_passed = False
    try:
        failures = [r for r in results if not isinstance(r, BackendPeer)]
        assert not failures, f"{len(failures)} of {SLOTS} peers failed to start: {failures!r}"
        for peer in peers:
            peer.check_alive()
        assert len({peer.chat_key for peer in peers}) == SLOTS, (
            f"expected {SLOTS} distinct peers, got {[p.chat_key for p in peers]!r}"
        )
        body_passed = True
    finally:
        failures = await stop_all(*peers)
        if body_passed and failures:
            # A leaked container or websocket thread poisons the next
            # test on this runner, so it cannot be a silent pass.
            raise failures[0]
