from types import SimpleNamespace
from unittest.mock import Mock

import pytest

from support import peer_chat_state


@pytest.mark.parametrize(
    ("row_tapped", "row_shows_composer"),
    [(True, True), (True, False), (False, False)],
)
def test_recover_peer_chat_prefers_the_messages_row(monkeypatch, row_tapped, row_shows_composer):
    device = SimpleNamespace(driver=object())
    peer = SimpleNamespace(alias="Peer Alias", display_name="Peer", chat_key="key1234")
    calls = Mock()
    chat_page = calls.chat_page
    chat_page.wait_for_message_input.side_effect = [False, False, row_shows_composer]
    chat_page.open_chat_by_suffix.return_value = row_tapped
    calls.open_link.return_value = True
    monkeypatch.setattr(peer_chat_state, "ChatPage", lambda _: chat_page)
    monkeypatch.setattr(peer_chat_state, "App", lambda _: calls.app)
    monkeypatch.setattr(peer_chat_state, "open_peer_chat_by_deeplink", calls.open_link)

    assert peer_chat_state.ensure_peer_chat_visible(device, peer) is chat_page

    chat_page.open_chat_by_suffix.assert_called_once_with(
        peer.alias, display_name=peer.display_name, timeout=5, allow_unique_row=False,
    )
    names = [call[0] for call in calls.mock_calls]
    row_tap = names.index("chat_page.open_chat_by_suffix")
    assert names.index("chat_page.dismiss_backup_prompt", names.index("app.click_messages_button")) < row_tap
    if row_shows_composer:
        calls.open_link.assert_not_called()
    else:
        calls.open_link.assert_called_once_with(device, peer)
        assert row_tap < names.index("open_link")
