import time


def poll(check, timeout_msec, interval=0.1):
    """The first truthy result of ``check()``, or None once ``timeout_msec`` has passed."""
    deadline = time.monotonic() + timeout_msec / 1000
    while not (result := check()):
        if time.monotonic() >= deadline:
            return None
        time.sleep(interval)
    return result
