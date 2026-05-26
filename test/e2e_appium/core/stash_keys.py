"""Central definitions for pytest stash keys used across the framework."""

from typing import Any, List, Tuple

from pytest import StashKey


# Each entry is a tuple of (device_results, session_managers, session_pool)
MULTI_DEVICE_MANAGERS_KEY: StashKey[List[Tuple[Any, Any, Any]]] = StashKey()


# Cache for messaging fixture (``established_chat``) failure across
# pytest-rerunfailures reruns. The rerun plugin clears pytest's
# ``cached_result`` on rerun, so without an external sentinel every
# messaging-test rerun re-pays the full ~14 min fixture-setup loop.
# The fixture checks this stash at entry and re-raises the cached
# exception instead of re-attempting setup. Scope is per-pytest-session,
# which under pytest-xdist means per-worker — exactly what we want.
ESTABLISHED_CHAT_BROKEN_KEY: StashKey[BaseException] = StashKey()


# Counter for ``established_chat`` fixture failures within a pytest session.
# pytest-rerunfailures owns retry via ``@pytest.mark.flaky(reruns=1)``; the
# sentinel above must only fire once that single retry is exhausted, otherwise
# the rerun re-raises the sentinel before getting a fresh setup attempt.
ESTABLISHED_CHAT_FAILURE_COUNT_KEY: StashKey[int] = StashKey()

