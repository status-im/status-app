"""Probe Windows IP Helper vs NIC counters. Run on the benchmark host:

    python scripts/utils/calibrate_network_metrics.py
"""

from __future__ import annotations

import os
import sys
import threading
import urllib.request


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, os.path.dirname(os.path.dirname(SCRIPT_DIR)))

from scripts.utils.network_metrics import (  # noqa: E402
    WindowsProcessNetworkCounter,
    nic_bytes_total,
    process_tree_pids,
)


def _download(url: str) -> int:
    with urllib.request.urlopen(url, timeout=30) as response:
        return len(response.read())


def main() -> int:
    pid = os.getpid()
    counter = WindowsProcessNetworkCounter(pid)
    before = counter.snapshot()
    nic_before = nic_bytes_total()
    print(f'pid={pid} tree={sorted(process_tree_pids(pid))}')
    print(
        f'before tcp_bytes={before.tcp_bytes} nic_bytes={before.nic_bytes} '
        f'conns={before.tcp_connections} source={before.source}'
    )
    stop = threading.Event()

    def poll() -> None:
        while not stop.wait(0.2):
            counter.snapshot()

    sampler = threading.Thread(target=poll, daemon=True)
    sampler.start()
    try:
        downloaded = _download('https://www.python.org/static/img/python-logo.png')
    finally:
        stop.set()
        sampler.join(timeout=2)
    after = counter.snapshot()
    nic_after = nic_bytes_total()
    tcp_delta = max(0, after.tcp_bytes - before.tcp_bytes)
    nic_delta = max(0, nic_after - nic_before)
    print(f'downloaded={downloaded} bytes')
    print(f'tcp_delta={tcp_delta} nic_delta={nic_delta} source={after.source}')
    if tcp_delta > downloaded * 0.5:
        print('OK: IP Helper ESTATS sees this process')
        return 0
    if nic_delta > downloaded * 0.5:
        print('WARN: ESTATS missed the transfer; NIC fallback would still see it')
        return 0
    print('FAIL: neither ESTATS nor NIC saw the download')
    return 1


if __name__ == '__main__':
    raise SystemExit(main())
