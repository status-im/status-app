"""Finding objects of the current app, and waiting for them."""

import os

from . import lookup, session
from .inspector import InspectorError
from .obj import Obj
from .poll import poll

DEFAULT_TIMEOUT_MSEC = 5000
# Optional file that receives, for each lookup that found nothing, which rule removed the candidates.
LOOKUP_LOG = os.environ.get("E2E_LOOKUP_LOG")


def _matches(locator, trace=None):
    if isinstance(locator, Obj):
        return [locator]
    inspector = session.inspector()
    root = None
    if (container := locator.get("container")) is not None:
        parents = _matches(container, trace)
        if not parents:
            return []
        root = parents[0]._id
    return [Obj(inspector, match) for match in lookup.find(inspector, locator, root, trace)]


def _try_matches(locator):
    try:
        return _matches(locator)
    except InspectorError:
        return []


_logged_misses = set()


def _log_miss(what, locator):
    if not LOOKUP_LOG or isinstance(locator, Obj):
        return
    trace = []
    try:
        _matches(locator, trace)
    except RuntimeError as error:
        trace.append(f"  (no explanation: {error})")
    text = "\n".join(trace)
    if (what, text) in _logged_misses:
        return
    _logged_misses.add((what, text))
    test = os.environ.get("PYTEST_CURRENT_TEST", "?").split(" ")[0].split("::")[-1]
    with open(LOOKUP_LOG, "a") as log:
        log.write(f"[{test}] {what}\n{text}\n")


def find_all(locator):
    found = _try_matches(locator)
    if not found:
        _log_miss("find_all found nothing", locator)
    return found


def find(locator):
    found = _try_matches(locator)
    if not found:
        raise LookupError(f"Object {locator} not found")
    return found[0]


def exists(locator):
    return bool(_try_matches(locator))


def _is_ready(obj):
    properties = obj._properties()
    return properties.get("visible", True) is not False and properties.get("enabled", True) is not False


def _wait(locator, timeout_msec, ready):
    if timeout_msec is None:
        timeout_msec = DEFAULT_TIMEOUT_MSEC

    def first_ready():
        for obj in _try_matches(locator):
            try:
                if ready(obj):
                    return obj
            except RuntimeError:
                # The object went away between the lookup and the check.
                pass
        return None

    found = poll(first_ready, timeout_msec)
    if found is None:
        # Tests probe with very short timeouts to ask "is it there?"; those are not failures.
        if timeout_msec >= 1000:
            _log_miss(f"wait timed out after {timeout_msec / 1000:g}s", locator)
        raise LookupError(f"Object {locator} not found or not ready in {timeout_msec / 1000:g}s")
    return found


def wait(locator, timeout_msec=None):
    """The first object that matches and is visible and enabled."""
    return _wait(locator, timeout_msec, _is_ready)


def wait_exists(locator, timeout_msec=None):
    return _wait(locator, timeout_msec, lambda obj: True)


def wait_until(condition, timeout_msec=20_000):
    return bool(poll(condition, timeout_msec))
