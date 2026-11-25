# Backend peer

## Purpose
Open a conversation with a headless peer for messaging tests.

## Requirements

### Requirement: Prefer the peer's Messages row to a chat link
When the composer is not open after entering Messages, the framework SHALL try
the row matching the peer's name or identifier before opening its chat link.

Checked by: `tests/test_peer_chat_state.py::test_recover_peer_chat_prefers_the_messages_row`

#### Scenario: The row opens the conversation
- **WHEN** tapping the peer's Messages row opens the composer
- **THEN** the framework SHALL continue without opening a chat link

#### Scenario: The row does not open the conversation
- **WHEN** the row is absent or the tap does not open the composer
- **THEN** the framework SHALL try the peer's chat link
