"""Environment-aware timeout helpers.

Different test environments have different propagation characteristics:

- ``local`` — Pi devices on shared LAN. Cross-device delivery is fast
  (typically <30s when the underlying status-go race isn't hitting).
- ``browserstack`` — geographically distributed cloud devices. Cross-device
  delivery rides over the public internet between BS data centres + Waku
  store nodes. Empirically slower; 180s is borderline (verified
  2026-05-02 — ``test_clear_history_is_local_only`` failed at 180s on BS).

Tests that assert cross-device delivery should use ``cross_device_timeout()``
rather than a hardcoded constant so they auto-tune per environment.
"""

import os


def cross_device_timeout() -> int:
    """Cross-device delivery timeout (seconds) for the current environment.

    Aligned with the MVDS resend cycle (60s base) + Waku
    MissingMessageVerifier ticker (60s):
      * Pi (local LAN): 180s — comfortably catches the 1st MVDS retry
        + first verifier tick.
      * BrowserStack (cloud): 300s — adds headroom for inter-region
        WAN latency between BS device + Waku store nodes.
    """
    env = os.environ.get("CURRENT_TEST_ENVIRONMENT", "browserstack").lower()
    return 300 if env == "browserstack" else 180
