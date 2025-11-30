"""Central definitions for pytest stash keys used across the framework."""

from typing import Any, List, Tuple

from pytest import StashKey


# Each entry is a tuple of (device_results, session_managers, session_pool)
MULTI_DEVICE_MANAGERS_KEY: StashKey[List[Tuple[Any, Any, Any]]] = StashKey()





