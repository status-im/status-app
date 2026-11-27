import json
import socket

import pytest

from driver import session
from driver.inspector import Inspector


@pytest.fixture
def app():
    with socket.create_server(("127.0.0.1", 0)) as server:
        yield server


def connect(app, timeout_sec=5.0):
    inspector = Inspector(app.getsockname()[1], timeout_sec=timeout_sec)
    peer, _ = app.accept()
    peer.settimeout(5)
    return inspector, peer


def read_request(peer):
    return json.loads(peer.makefile("rb").readline())


def reply(peer, **fields):
    peer.sendall(json.dumps(fields).encode() + b"\n")


def assert_closed(peer):
    assert peer.recv(1) == b""


def test_closing_a_session_closes_the_connection_while_the_inspector_is_still_referenced(app):
    inspector, peer = connect(app)
    with peer:
        session.Session("app", inspector).close()
        assert_closed(peer)


def test_a_reply_to_another_request_closes_the_connection(app):
    inspector, peer = connect(app)
    with peer:
        reply(peer, id=999, tree={})
        with pytest.raises(ConnectionError):
            inspector.send("getTree")
        read_request(peer)
        assert_closed(peer)
        with pytest.raises(ConnectionError):
            inspector.send("getTree")


def test_a_timeout_closes_the_connection(app):
    inspector, peer = connect(app, timeout_sec=0.2)
    with peer:
        with pytest.raises(TimeoutError):
            inspector.send("getTree")
        read_request(peer)
        assert_closed(peer)


def test_the_reply_to_the_request_is_returned(app):
    inspector, peer = connect(app)
    with peer:
        reply(peer, id=1, properties=[])
        assert inspector.send("getProperties", objectId="1") == {"id": 1, "properties": []}
        assert read_request(peer) == {"id": 1, "command": "getProperties", "params": {"objectId": "1"}}
        inspector.close()
