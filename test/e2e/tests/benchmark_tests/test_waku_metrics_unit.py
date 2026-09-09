"""Unit tests for status-go prometheus scrape parsing."""

import unittest

from scripts.utils.waku_metrics import (
    WakuMetricsUnavailable,
    delta_by_name,
    parse_data_usage_snapshot,
    parse_status_http_by_host,
    parse_waku_bandwidth_bytes,
)


class WakuMetricsParseTests(unittest.TestCase):
    def test_sums_in_and_out_counters(self):
        text = (
            '# HELP waku_libp2p_bandwidth_bytes Cumulative libp2p Waku bytes.\n'
            '# TYPE waku_libp2p_bandwidth_bytes counter\n'
            'waku_libp2p_bandwidth_bytes{dir="in"} 2000\n'
            'waku_libp2p_bandwidth_bytes{dir="out"} 1000\n'
        )
        self.assertEqual(parse_waku_bandwidth_bytes(text), 3000)

    def test_accepts_optional_prometheus_timestamp(self):
        text = (
            'waku_libp2p_bandwidth_bytes{dir="in"} 10 1710000000\n'
            'waku_libp2p_bandwidth_bytes{dir="out"} 5 1710000000\n'
        )
        self.assertEqual(parse_waku_bandwidth_bytes(text), 15)

    def test_missing_counters_raise(self):
        with self.assertRaises(WakuMetricsUnavailable):
            parse_waku_bandwidth_bytes('# TYPE go_goroutines gauge\ngo_goroutines 12\n')

    def test_missing_waku_optional_is_zero(self):
        snapshot = parse_data_usage_snapshot(
            '# TYPE go_goroutines gauge\ngo_goroutines 12\n',
            require_waku=False,
        )
        self.assertEqual(snapshot.waku_bytes, 0)
        self.assertEqual(snapshot.http_by_host, {})


class HttpMetricsParseTests(unittest.TestCase):
    def test_http_bytes_sum_by_host(self):
        text = (
            'status_http_bytes{dir="in",host="prod.market.status.im"} 1000\n'
            'status_http_bytes{dir="out",host="prod.market.status.im"} 200\n'
            'status_http_bytes{host="prod.eth-rpc.status.im",dir="in"} 50\n'
        )
        self.assertEqual(parse_status_http_by_host(text), {
            'prod.market.status.im': 1200,
            'prod.eth-rpc.status.im': 50,
        })

    def test_missing_http_is_empty(self):
        text = (
            'waku_libp2p_bandwidth_bytes{dir="in"} 1\n'
            'waku_libp2p_bandwidth_bytes{dir="out"} 1\n'
        )
        snapshot = parse_data_usage_snapshot(text)
        self.assertEqual(snapshot.waku_bytes, 2)
        self.assertEqual(snapshot.http_by_host, {})

    def test_delta_by_name_keeps_positive_growth(self):
        self.assertEqual(
            delta_by_name({'a': 10, 'b': 5}, {'a': 15, 'b': 5, 'c': 3}),
            {'a': 5, 'c': 3},
        )


if __name__ == '__main__':
    unittest.main()
