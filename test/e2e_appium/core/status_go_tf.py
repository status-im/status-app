"""Locating and importing the status-go functional-test client."""
from __future__ import annotations

import functools
import importlib
import importlib.util
import inspect
import os
import sys
from typing import NamedTuple

import requests

_TF_LAYOUTS = ("test/functional",)
_CLIENT_PACKAGES = ("clients", "resources", "utils")

# The client posts without a timeout, so a peer that accepts a connection and
# never answers would otherwise hold a worker until the test timeout.
RPC_TIMEOUT_SECONDS = int(os.environ.get("STATUS_BACKEND_RPC_TIMEOUT", "60"))


class BoundedSession(requests.Session):
    """A session that supplies a timeout unless the caller passed one."""

    def __init__(self, timeout=(5, RPC_TIMEOUT_SECONDS)):
        super().__init__()
        self._timeout = timeout

    def request(self, method, url, **kwargs):
        kwargs.setdefault("timeout", self._timeout)
        return super().request(method, url, **kwargs)


class TfClient(NamedTuple):
    StatusBackend: type
    Config: type


def repo_root() -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.abspath(os.path.join(here, "..", "..", ".."))


def tf_candidates(root: str | None = None) -> list[str]:
    """Where the functional-test client lives under the vendored submodule."""
    base = os.path.join(root or repo_root(), "vendor", "status-go")
    return [os.path.abspath(os.path.join(base, layout)) for layout in _TF_LAYOUTS]


def tf_root(root: str | None = None) -> str:
    """Resolve the functional-test client directory."""
    env = os.environ.get("STATUS_GO_TESTS_FUNCTIONAL")
    if env:
        return os.path.abspath(env)

    candidates = tf_candidates(root)
    for candidate in candidates:
        if os.path.isdir(os.path.join(candidate, "clients")):
            return candidate

    raise RuntimeError(
        "status-go functional-test client not found. Looked for a 'clients' "
        "directory under: " + ", ".join(candidates) + ". The vendored "
        "submodule is probably not checked out (git submodule update --init "
        "vendor/status-go); if it is, status-go has moved the tree and "
        "_TF_LAYOUTS needs the new path. Set STATUS_GO_TESTS_FUNCTIONAL to "
        "point at it directly."
    )


_cached: TfClient | None = None


def _import_client(tf: str):
    """Import the client with its tree first on the path, then put back any of
    this suite's packages that share a top-level name. The client's modules keep
    the objects they bound at import; its only lazy import is of its own
    ``clients`` package, which nothing here shares."""
    colliding = set()
    for name in _CLIENT_PACKAGES:
        try:
            found = importlib.util.find_spec(name) is not None
        except ValueError:
            found = True
        if found:
            colliding.add(name)
    saved = {k: sys.modules.pop(k) for k in list(sys.modules)
             if k.split(".")[0] in colliding}
    sys.path.insert(0, tf)
    try:
        sb = importlib.import_module("clients.status_backend")
        cfg = importlib.import_module("utils.config")
    finally:
        sys.path.remove(tf)
        sys.path.append(tf)
        for k in [k for k in sys.modules if k.split(".")[0] in colliding]:
            del sys.modules[k]
        sys.modules.update(saved)
    return sb, cfg


def load_tf_client() -> TfClient:
    global _cached
    if _cached is not None:
        return _cached

    tf = tf_root()
    try:
        sb, cfg = _import_client(tf)
    except ModuleNotFoundError as exc:
        raise RuntimeError(
            f"status-go functional-test client at {tf} could not be imported: {exc}. "
            "Its dependencies are not in the e2e_appium gate install; "
            "run pip install -r requirements-backend-peer.txt."
        ) from exc

    bind_session_constructors(sb.StatusBackend)
    assert_session_constructors_bound(sb.StatusBackend)
    _cached = TfClient(sb.StatusBackend, cfg.Config)
    return _cached


def session_constructors(backend: type) -> list[type]:
    """The classes in the backend's ancestry whose own constructor takes the
    HTTP session, in resolution order. Each one assigns it, and the last
    assignment wins, so every one of them has to be bound."""
    found = []
    for cls in backend.__mro__:
        init = vars(cls).get("__init__")
        if init is not None and "client" in inspect.signature(init).parameters:
            found.append(cls)
    return found


def bind_session_constructors(backend: type) -> None:
    for cls in session_constructors(backend):
        _bind_request_timeouts(cls)


def assert_session_constructors_bound(backend: type) -> None:
    """Raise if any constructor that installs a session is still unbounded."""
    unbound = [
        cls.__name__ for cls in session_constructors(backend)
        if not getattr(cls.__init__, "_bounded", False)
    ]
    if unbound:
        raise RuntimeError(
            f"{', '.join(unbound)} would give {backend.__name__} an unbounded "
            "HTTP session; a peer that accepts a connection and never answers "
            "would then hold a worker until the test timeout."
        )


def _bind_request_timeouts(cls: type) -> None:
    """The client builds its session inside its own constructor and health-checks
    with it before a caller can replace it, so the timeout has to be installed
    there rather than on the object afterwards."""
    if getattr(cls.__init__, "_bounded", False):
        return
    unbounded = cls.__init__

    @functools.wraps(unbounded)
    def __init__(self, *args, **kwargs):
        # The client never passes a session positionally; one that did would get
        # a TypeError here rather than a silently unbounded session.
        kwargs.setdefault("client", BoundedSession())
        unbounded(self, *args, **kwargs)

    __init__._bounded = True
    cls.__init__ = __init__
