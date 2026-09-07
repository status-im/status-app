"""Device-free checks on the peer core: image provenance, the request-timeout
bind on the status-go client, container start-up errors, liveness on a failing
probe, and identity recovery when the login signal was missed."""
import importlib
import os
import sys
from concurrent.futures import ThreadPoolExecutor

import pytest

from core import backend_peer, peer_containers
from core.backend_peer import BackendPeer, PeerDied
from core.peer_containers import PeerProvenanceError, check_provenance
from core.status_go_tf import (
    BoundedSession,
    assert_session_constructors_bound,
    bind_session_constructors,
    session_constructors,
    tf_candidates,
)

VENDORED = "27bca1fc5ce82a3fc5022bfde93c0fd32c1dc997"
DIGEST = "@sha256:" + "a" * 64


# --- provenance: the tag names the commit, whatever reference form wraps it ---

@pytest.mark.parametrize("ref", [
    "statusgo-peer-27bca1fc5ce8",
    "statusgo-peer-27bca1fc5ce8:latest",
    "statusgo-peer-27bca1fc5ce8:v1",
    "localhost:5000/statusgo-peer-27bca1fc5ce8:latest",
    "statusgo-peer-27bca1fc5ce8" + DIGEST,
    "statusgo-peer-27bca1fc5ce8:latest" + DIGEST,
])
def test_every_reference_form_of_the_built_image_is_accepted(ref):
    assert check_provenance(ref, VENDORED) == "27bca1fc5ce8"


@pytest.mark.parametrize("ref", [
    "statusgo:latest",
    "statusgo-peer",
    "random-image-27bca1fc5ce8",
    "statusgo" + DIGEST,
])
def test_an_image_that_names_no_commit_is_refused_as_unknown(ref):
    with pytest.raises(PeerProvenanceError, match="provenance is unknown"):
        check_provenance(ref, VENDORED)


def test_a_digest_is_never_read_as_the_commit():
    with pytest.raises(PeerProvenanceError, match="provenance is unknown") as info:
        check_provenance("statusgo" + DIGEST, VENDORED)
    assert "built from aaaa" not in str(info.value)


@pytest.mark.parametrize("ref", [
    "statusgo-peer-deadbeef",
    "statusgo-peer-deadbeef:latest",
])
def test_an_image_from_another_commit_is_refused(ref):
    with pytest.raises(PeerProvenanceError, match="vendors"):
        check_provenance(ref, VENDORED)


def test_a_too_short_prefix_is_refused():
    with pytest.raises(PeerProvenanceError, match="provenance is unknown"):
        check_provenance("statusgo-peer-27bca", VENDORED)


# --- the timeout bind: every constructor that installs a session -------------

def _unbound_api_init(self, api_url, client=None):
    self.api_url = api_url
    self.client = client


def _backend_shape():
    """The pinned client's shape, built fresh so binding one test's classes
    cannot leak into another: the composite calls the rpc constructor, then the
    api constructor, and the second assigns the session again."""
    class Api:
        __init__ = _unbound_api_init

    class Rpc(Api):
        def __init__(self, client=None):
            self.client = client

    class Signal:
        def __init__(self, url):
            self.url = url

    class Backend(Rpc, Signal, Api):
        def __init__(self, url="http://peer"):
            Rpc.__init__(self)
            Signal.__init__(self, url)
            Api.__init__(self, url)

    return Backend, Rpc, Api


def test_the_session_constructors_are_the_ones_that_take_a_client():
    backend, rpc, api = _backend_shape()
    assert session_constructors(backend) == [rpc, api]


def test_binding_reaches_the_last_assignment_of_the_session():
    backend, _, _ = _backend_shape()
    bind_session_constructors(backend)
    assert isinstance(backend().client, BoundedSession)


def test_an_unbound_session_constructor_is_reported_by_name():
    backend, _rpc, api = _backend_shape()
    bind_session_constructors(backend)
    api.__init__ = _unbound_api_init
    with pytest.raises(RuntimeError, match="Api"):
        assert_session_constructors_bound(backend)


@pytest.mark.skipif(
    not any(os.path.isdir(os.path.join(c, "clients")) for c in tf_candidates())
    and not os.environ.get("STATUS_GO_TESTS_FUNCTIONAL"),
    reason="the status-go functional-test client is not checked out",
)
def test_the_vendored_client_loads_with_every_session_constructor_bound():
    from core.status_go_tf import load_tf_client

    client = load_tf_client()
    names = {cls.__name__ for cls in session_constructors(client.StatusBackend)}
    assert names == {"RpcClient", "ApiClient"}
    assert_session_constructors_bound(client.StatusBackend)


# --- container start-up ------------------------------------------------------

class _Client:
    def __init__(self, exc):
        self.calls = 0
        self.exc = exc

    def StatusBackend(self):
        self.calls += 1
        raise self.exc


def test_a_missing_image_is_refused_before_starting_a_peer():
    docker = pytest.importorskip("docker")

    class _Images:
        def get(self, _image_ref):
            raise docker.errors.ImageNotFound("x")

    class _Docker:
        images = _Images()

    with pytest.raises(RuntimeError, match="peer_image.sh"):
        peer_containers.check_docker_resources("statusgo-peer-image", "peer", _Docker())


def test_a_missing_network_is_refused_before_starting_a_peer():
    docker = pytest.importorskip("docker")

    class _Images:
        def get(self, _image_ref):
            return object()

    class _Networks:
        def get(self, _network):
            raise docker.errors.NotFound("x")

    class _Docker:
        images = _Images()
        networks = _Networks()

    with pytest.raises(RuntimeError, match="peer_image.sh"):
        peer_containers.check_docker_resources("statusgo-peer-image", "peer", _Docker())


def test_a_backend_that_is_still_starting_is_retried(monkeypatch):
    monkeypatch.setattr(backend_peer.time, "sleep", lambda _s: None)
    client = _Client(RuntimeError("health check failed"))
    with pytest.raises(RuntimeError, match="health check"):
        backend_peer._start_container_backend(client)
    assert client.calls == backend_peer.CONTAINER_START_ATTEMPTS


def test_configure_runs_once_per_process(monkeypatch):
    monkeypatch.setenv(peer_containers.IMAGE_ENV, "statusgo-peer-27bca1fc5ce8")
    monkeypatch.setenv(peer_containers.PROJECT_ENV, "peer-test")
    monkeypatch.setattr(peer_containers, "vendored_status_go_sha", lambda _root: VENDORED)
    calls = []
    monkeypatch.setattr(
        peer_containers, "check_docker_resources",
        lambda image_ref, project: calls.append((image_ref, project)),
    )
    monkeypatch.setattr(peer_containers, "_configured", None)

    class _Cfg:
        pass

    config = _Cfg()
    with ThreadPoolExecutor(max_workers=5) as pool:
        futures = [pool.submit(peer_containers.configure, config) for _ in range(5)]
        for future in futures:
            future.result()

    assert len(calls) == 1
    assert config.logs_dir.endswith(os.path.join("logs", "backend_peer"))
    assert config.status_backend_urls is None


@pytest.mark.asyncio
async def test_a_failed_onboard_reports_its_own_error_not_the_cleanup_error(monkeypatch):
    """The reason onboarding failed is the useful one; a cleanup failure on top
    of it must not replace it."""
    class _Peer:
        def __init__(self, *_a, **_k):
            self.fleet = "status.prod"
            self.node_fleet = ""

        async def onboard(self):
            raise RuntimeError("login never completed")

        async def stop(self):
            raise RuntimeError("docker daemon went away")

    monkeypatch.setattr(backend_peer, "BackendPeer", _Peer)
    with pytest.raises(RuntimeError, match="login never completed"):
        await backend_peer.onboarded("AnyPeer")


def test_configure_reapplies_the_config_when_the_checks_are_cached(monkeypatch):
    """A peer reached over a url leaves status_backend_urls set. The next
    container peer must clear it, or the client never starts a container."""
    monkeypatch.setenv(peer_containers.IMAGE_ENV, "statusgo-peer-27bca1fc5ce8")
    monkeypatch.setenv(peer_containers.PROJECT_ENV, "peer-test")
    monkeypatch.setattr(peer_containers, "vendored_status_go_sha", lambda _root: VENDORED)
    monkeypatch.setattr(peer_containers, "check_docker_resources", lambda *_: None)
    monkeypatch.setattr(peer_containers, "_configured", None)

    class _Cfg:
        pass

    config = _Cfg()
    peer_containers.configure(config)
    config.status_backend_urls = iter(["http://peer:3333"])

    peer_containers.configure(config)

    assert config.status_backend_urls is None
    assert config.docker_image == "statusgo-peer-27bca1fc5ce8"


@pytest.mark.asyncio
async def test_stop_all_reports_but_does_not_raise_teardown_failures():
    class _GoodPeer:
        async def stop(self):
            return None

    class _BadPeer:
        async def stop(self):
            raise RuntimeError("teardown failed")

    failures = await backend_peer.stop_all(_GoodPeer(), _BadPeer())
    assert len(failures) == 1
    assert isinstance(failures[0], RuntimeError)


def test_peers_in_one_process_must_share_a_fleet(monkeypatch):
    monkeypatch.setattr(backend_peer, "_process_fleet", "status.prod")
    with pytest.raises(RuntimeError, match="process-global"):
        backend_peer._claim_process_fleet("status.test")
    backend_peer._claim_process_fleet("status.prod")


def test_the_client_is_imported_even_when_this_suite_has_a_utils_package(tmp_path, monkeypatch):
    suite = tmp_path / "suite"
    suite_utils = suite / "utils"
    suite_utils.mkdir(parents=True)
    (suite_utils / "__init__.py").write_text("")
    (suite_utils / "other.py").write_text("X = 1\n")

    tf = tmp_path / "tf"
    clients = tf / "clients"
    tf_utils = tf / "utils"
    clients.mkdir(parents=True)
    tf_utils.mkdir(parents=True)
    (clients / "__init__.py").write_text("")
    (clients / "status_backend.py").write_text(
        "from utils.config import Config\n"
        "class StatusBackend:\n"
        "    def __init__(self): pass\n"
    )
    (tf_utils / "__init__.py").write_text("")
    (tf_utils / "config.py").write_text('class Config:\n    marker = "client"\n')

    saved_modules = {
        name: module for name, module in sys.modules.items()
        if name.split(".")[0] in {"clients", "utils"}
    }
    for name in list(saved_modules):
        sys.modules.pop(name)
    monkeypatch.syspath_prepend(str(suite))
    monkeypatch.setenv("STATUS_GO_TESTS_FUNCTIONAL", str(tf))
    from core import status_go_tf

    status_go_tf._cached = None
    try:
        client = status_go_tf.load_tf_client()
        assert client.Config.marker == "client"
        assert importlib.import_module("utils.other").X == 1
        assert str(suite) in sys.modules["utils"].__file__
    finally:
        status_go_tf._cached = None
        for name in list(sys.modules):
            if name.split(".")[0] in {"clients", "utils"}:
                sys.modules.pop(name)
        sys.modules.update(saved_modules)


# --- a probe that fails because the peer died says so --------------------------

class _Container:
    name = "peer-x-status-backend"

    def __init__(self):
        self.status = "running"
        self.reloads = 0

    def reload(self):
        self.reloads += 1
        if self.reloads > 1:
            self.status = "exited"

    def logs(self, tail=None):
        return b"fatal: out of memory"


async def test_a_dead_peer_is_reported_even_when_the_probe_raised():
    peer = BackendPeer()
    container = _Container()
    peer._container = lambda: container

    def probe():
        raise ConnectionError("connection refused")

    with pytest.raises(PeerDied, match="out of memory"):
        await peer._await("anything", probe, timeout=5)


# --- identity when the login signal was missed -------------------------------

class _Settings:
    def __init__(self, settings):
        self.settings = settings
        self.calls = 0

    def get_settings(self):
        self.calls += 1
        return self.settings


class _Backend:
    def __init__(self, event, settings):
        self.node_login_event = event
        self.settings_service = _Settings(settings)


FULL = {"compressedKey": "zQ3shPeer", "public-key": "0x04peer", "fleet": "status.prod", "alias": "a b c"}


def test_identity_comes_from_the_login_signal_when_it_carries_it():
    be = _Backend({"event": {"settings": FULL}}, {})
    assert backend_peer.login_identity(be) == FULL
    assert be.settings_service.calls == 0


def test_identity_is_read_from_the_backend_when_nothing_cached_it():
    peer = BackendPeer()
    peer._sync = _Backend({"event": {"settings": FULL}}, {})
    assert peer.public_key == "0x04peer"
    assert peer.chat_key == "zQ3shPeer"


def test_identity_is_recovered_from_settings_when_the_signal_was_rebuilt_over_rpc():
    rebuilt = {"public-key": "0x04peer", "mnemonic": "m"}
    be = _Backend({"event": {"settings": rebuilt}}, FULL)
    identity = backend_peer.login_identity(be)
    assert identity["compressedKey"] == "zQ3shPeer"
    assert identity["fleet"] == "status.prod"
    assert identity["mnemonic"] == "m"
    assert be.settings_service.calls == 1
