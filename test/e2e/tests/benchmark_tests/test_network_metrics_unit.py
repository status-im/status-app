"""Unit tests for data-usage settle detection. No Status app required."""

import unittest

from scripts.utils.network_metrics import (
    _rate_settled,
    is_https_remote_port,
    wait_until_settled,
)


class SettleDetectionTests(unittest.TestCase):
    def test_rate_settled_when_window_is_quiet(self):
        samples = [
            (0.0, 0),
            (15.0, 5_000_000),
            (30.0, 5_100_000),
            (45.0, 5_200_000),
        ]
        self.assertTrue(_rate_settled(samples, 15.0, 25 * 1024))

    def test_rate_not_settled_during_burst(self):
        samples = [
            (0.0, 0),
            (2.0, 2_000_000),
            (4.0, 4_000_000),
        ]
        self.assertFalse(_rate_settled(samples, 15.0, 25 * 1024))

    def test_wait_until_settled_stops_after_quiet_window(self):
        clock = {'now': 0.0}
        bytes_at = {0.0: 0}

        def monotonic():
            return clock['now']

        def sleep(seconds):
            clock['now'] += seconds
            # After 30s the transfer has already finished.
            bytes_at[clock['now']] = 3_000_000 if clock['now'] < 32 else 3_010_000

        def read_bytes():
            return bytes_at[max(key for key in bytes_at if key <= clock['now'])]

        result = wait_until_settled(
            read_bytes,
            min_wait_sec=30.0,
            max_wait_sec=90.0,
            sample_interval_sec=2.0,
            settle_window_sec=15.0,
            settle_rate_bytes_per_sec=25 * 1024,
            sleep=sleep,
            monotonic=monotonic,
        )
        self.assertFalse(result.hit_cap)
        self.assertGreaterEqual(result.elapsed_sec, 30.0)
        self.assertLess(result.elapsed_sec, 90.0)
        self.assertGreater(result.incremental_bytes, 2_900_000)
        self.assertLess(result.incremental_bytes, 3_100_000)

    def test_wait_until_settled_hits_cap_when_never_quiet(self):
        clock = {'now': 0.0}

        def monotonic():
            return clock['now']

        def sleep(seconds):
            clock['now'] += seconds

        def read_bytes():
            return int(clock['now'] * 500_000)

        result = wait_until_settled(
            read_bytes,
            min_wait_sec=30.0,
            max_wait_sec=40.0,
            sample_interval_sec=2.0,
            settle_window_sec=15.0,
            settle_rate_bytes_per_sec=25 * 1024,
            sleep=sleep,
            monotonic=monotonic,
        )
        self.assertTrue(result.hit_cap)
        self.assertGreaterEqual(result.elapsed_sec, 40.0)

    def test_wait_until_settled_without_cap_keeps_waiting(self):
        clock = {'now': 0.0}
        bytes_at = {0.0: 0}

        def monotonic():
            return clock['now']

        def sleep(seconds):
            clock['now'] += seconds
            # Burst until 120s, then go quiet.
            bytes_at[clock['now']] = (
                int(clock['now'] * 400_000) if clock['now'] < 120 else 48_010_000
            )

        def read_bytes():
            return bytes_at[max(key for key in bytes_at if key <= clock['now'])]

        result = wait_until_settled(
            read_bytes,
            min_wait_sec=30.0,
            max_wait_sec=None,
            sample_interval_sec=2.0,
            settle_window_sec=15.0,
            settle_rate_bytes_per_sec=25 * 1024,
            sleep=sleep,
            monotonic=monotonic,
        )
        self.assertFalse(result.hit_cap)
        self.assertGreaterEqual(result.elapsed_sec, 120.0)


class HttpsPortTests(unittest.TestCase):
    def test_network_byte_order_443_is_https(self):
        import socket
        self.assertTrue(is_https_remote_port(socket.htons(443)))
        self.assertFalse(is_https_remote_port(socket.htons(80)))
        self.assertFalse(is_https_remote_port(socket.htons(30303)))


if __name__ == '__main__':
    unittest.main()
