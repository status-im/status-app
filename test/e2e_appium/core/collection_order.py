"""Hand the longest test modules to xdist first.

The loadscope scheduler pops work units from the front of the collection order
(``workqueue.popitem(last=False)``) and gives a worker the next module whenever
it goes free. A long module collected last is therefore started alone, after
every other worker has run dry, and the whole run waits for it. Longest-first
puts the short modules in that tail instead.
"""

# Seconds per module, from a green five-worker run. Only used for ordering, so
# drift costs a little balance, never correctness.
MODULE_SECONDS = {
    "tests/messaging/test_z_chat_management_backend.py": 769,
    "tests/messaging/test_message_actions_backend.py": 743,
    "tests/test_onboarding_import_seed.py": 516,
    "tests/messaging/test_message_received_backend.py": 372,
    "tests/test_navigation_drawer.py": 367,
    "tests/test_wallet_accounts_basic.py": 338,
    "tests/test_settings_password_change_password.py": 286,
}

# An unlisted module is assumed heavy so a newly added one is scheduled early
# rather than becoming the tail. Guessing high costs nothing: a module that
# turns out to be quick just frees its worker sooner.
UNKNOWN_MODULE_SECONDS = 300


def module_of(nodeid: str) -> str:
    return nodeid.split("::", 1)[0]


def module_cost(nodeid: str) -> int:
    return MODULE_SECONDS.get(module_of(nodeid), UNKNOWN_MODULE_SECONDS)


def heaviest_first(items: list) -> list:
    """``items`` reordered so whole modules run longest-first.

    Order inside a module is left alone: some classes carry state from one test
    to the next.
    """
    first_seen: dict[str, int] = {}
    for index, item in enumerate(items):
        first_seen.setdefault(module_of(item.nodeid), index)
    return sorted(
        items,
        key=lambda item: (-module_cost(item.nodeid), first_seen[module_of(item.nodeid)]),
    )
