"""Per-process network usage for Status Desktop on Windows.

Counts TCP payload bytes for the AUT process tree via IP Helper ESTATS,
excluding loopback. Falls back to non-loopback NIC counters when ESTATS is
unavailable. Used by first-open data-usage benchmarks.
"""

from __future__ import annotations

import ctypes
import logging
import socket
import struct
import threading
import time
from ctypes import wintypes
from dataclasses import dataclass
from typing import Callable, Optional

import psutil

LOG = logging.getLogger(__name__)

MIN_WAIT_SEC = 30.0
MAX_WAIT_SEC = 300.0
SAMPLE_INTERVAL_SEC = 2.0
SETTLE_WINDOW_SEC = 15.0
SETTLE_RATE_BYTES_PER_SEC = 25 * 1024
_PROGRESS_LOG_SEC = 30.0

_AF_INET = 2
_AF_INET6 = 23
_TCP_TABLE_OWNER_PID_ALL = 5
_UDP_TABLE_OWNER_PID = 1
_TCP_ESTATS_DATA = 1
_ERROR_INSUFFICIENT_BUFFER = 122
_NO_ERROR = 0
_LOOPBACK_V4_PREFIX = '127.'
_IPV6_LOOPBACK = bytes.fromhex('00000000000000000000000000000001')
_IPV6_UNSPECIFIED = bytes(16)


_HTTPS_PORTS = {443}


def remote_port_host(port_nbo: int) -> int:
    return socket.ntohs(port_nbo & 0xFFFF)


def is_https_remote_port(port_nbo: int) -> bool:
    return remote_port_host(port_nbo) in _HTTPS_PORTS


@dataclass(frozen=True)
class NetworkSnapshot:
    app_bytes: int
    tcp_bytes: int
    https_bytes: int
    nic_bytes: int
    tcp_connections: int
    udp_endpoints: int
    source: str


@dataclass(frozen=True)
class SettleResult:
    incremental_bytes: int
    elapsed_sec: float
    hit_cap: bool
    sample_count: int
    source: str
    https_bytes: int = 0
    udp_bytes: int = 0

    @property
    def incremental_mb(self) -> float:
        return self.incremental_bytes / (1024 * 1024)


def process_tree_pids(pid: int) -> set[int]:
    pids = {pid}
    try:
        root = psutil.Process(pid)
        pids.update(child.pid for child in root.children(recursive=True))
    except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
        LOG.debug('AUT process tree unavailable for pid=%s', pid)
    return pids


def nic_bytes_total() -> int:
    """Sum RX+TX on real adapters, skipping loopback."""
    try:
        pernic = psutil.net_io_counters(pernic=True)
    except (psutil.Error, OSError) as error:
        LOG.debug('NIC counters unavailable: %s', error)
        return 0
    total = 0
    for name, stats in pernic.items():
        lowered = name.lower()
        if 'loopback' in lowered or lowered.startswith('lo'):
            continue
        total += int(stats.bytes_sent) + int(stats.bytes_recv)
    return total


def wait_until_settled(
    read_bytes: Callable[[], int],
    *,
    min_wait_sec: float = MIN_WAIT_SEC,
    max_wait_sec: Optional[float] = MAX_WAIT_SEC,
    sample_interval_sec: float = SAMPLE_INTERVAL_SEC,
    settle_window_sec: float = SETTLE_WINDOW_SEC,
    settle_rate_bytes_per_sec: float = SETTLE_RATE_BYTES_PER_SEC,
    sleep: Callable[[float], None] = time.sleep,
    monotonic: Callable[[], float] = time.monotonic,
    source: str = 'tcp',
) -> SettleResult:
    """Watch cumulative bytes until the rate drops or max_wait is hit.

    ``max_wait_sec=None`` waits until quiet. Default cap is 5 minutes.
    """
    started_at = monotonic()
    origin = read_bytes()
    samples: list[tuple[float, int]] = [(0.0, 0)]
    last_log = 0.0
    while True:
        sleep(sample_interval_sec)
        elapsed = monotonic() - started_at
        delta = max(0, read_bytes() - origin)
        samples.append((elapsed, delta))
        if elapsed - last_log >= _PROGRESS_LOG_SEC:
            LOG.info(
                'settle wait %.0fs so far, %.3f MB, source=%s',
                elapsed, delta / (1024 * 1024), source,
            )
            last_log = elapsed
        if elapsed < min_wait_sec:
            continue
        if _rate_settled(samples, settle_window_sec, settle_rate_bytes_per_sec):
            return SettleResult(
                incremental_bytes=delta,
                elapsed_sec=elapsed,
                hit_cap=False,
                sample_count=len(samples),
                source=source,
            )
        if max_wait_sec is not None and elapsed >= max_wait_sec:
            return SettleResult(
                incremental_bytes=delta,
                elapsed_sec=elapsed,
                hit_cap=True,
                sample_count=len(samples),
                source=source,
            )


def _rate_settled(
    samples: list[tuple[float, int]],
    settle_window_sec: float,
    settle_rate_bytes_per_sec: float,
) -> bool:
    latest_time, latest_bytes = samples[-1]
    window_start = latest_time - settle_window_sec
    prior = [sample for sample in samples if sample[0] <= window_start]
    if not prior:
        return False
    _, bytes_at_window_start = prior[-1]
    gained = latest_bytes - bytes_at_window_start
    elapsed = latest_time - prior[-1][0]
    if elapsed <= 0:
        return False
    return (gained / elapsed) <= settle_rate_bytes_per_sec


class _MIB_TCPROW(ctypes.Structure):
    _fields_ = [
        ('dwState', wintypes.DWORD),
        ('dwLocalAddr', wintypes.DWORD),
        ('dwLocalPort', wintypes.DWORD),
        ('dwRemoteAddr', wintypes.DWORD),
        ('dwRemotePort', wintypes.DWORD),
    ]


class _MIB_TCPROW_OWNER_PID(ctypes.Structure):
    _fields_ = [
        ('dwState', wintypes.DWORD),
        ('dwLocalAddr', wintypes.DWORD),
        ('dwLocalPort', wintypes.DWORD),
        ('dwRemoteAddr', wintypes.DWORD),
        ('dwRemotePort', wintypes.DWORD),
        ('dwOwningPid', wintypes.DWORD),
    ]


class _MIB_TCP6ROW(ctypes.Structure):
    _fields_ = [
        ('dwState', wintypes.DWORD),
        ('LocalAddr', ctypes.c_ubyte * 16),
        ('dwLocalScopeId', wintypes.DWORD),
        ('dwLocalPort', wintypes.DWORD),
        ('RemoteAddr', ctypes.c_ubyte * 16),
        ('dwRemoteScopeId', wintypes.DWORD),
        ('dwRemotePort', wintypes.DWORD),
    ]


class _MIB_TCP6ROW_OWNER_PID(ctypes.Structure):
    _fields_ = [
        ('ucLocalAddr', ctypes.c_ubyte * 16),
        ('dwLocalScopeId', wintypes.DWORD),
        ('dwLocalPort', wintypes.DWORD),
        ('ucRemoteAddr', ctypes.c_ubyte * 16),
        ('dwRemoteScopeId', wintypes.DWORD),
        ('dwRemotePort', wintypes.DWORD),
        ('dwState', wintypes.DWORD),
        ('dwOwningPid', wintypes.DWORD),
    ]


class _MIB_UDPROW_OWNER_PID(ctypes.Structure):
    _fields_ = [
        ('dwLocalAddr', wintypes.DWORD),
        ('dwLocalPort', wintypes.DWORD),
        ('dwOwningPid', wintypes.DWORD),
    ]


class _TCP_ESTATS_DATA_RW_v0(ctypes.Structure):
    _fields_ = [('EnableCollection', ctypes.c_ubyte)]


class _TCP_ESTATS_DATA_ROD_v0(ctypes.Structure):
    _fields_ = [
        ('DataBytesOut', ctypes.c_uint64),
        ('DataSegsOut', ctypes.c_uint64),
        ('DataBytesIn', ctypes.c_uint64),
        ('DataSegsIn', ctypes.c_uint64),
        ('SegsOut', ctypes.c_uint64),
        ('SegsIn', ctypes.c_uint64),
        ('SoftErrors', ctypes.c_uint64),
        ('SoftErrorReason', ctypes.c_uint64),
        ('SndUna', ctypes.c_uint64),
        ('SndNxt', ctypes.c_uint64),
        ('SndMax', ctypes.c_uint64),
        ('ThruBytesAcked', ctypes.c_uint64),
        ('RcvNxt', ctypes.c_uint64),
        ('ThruBytesReceived', ctypes.c_uint64),
    ]


def _ipv4_text(addr: int) -> str:
    return socket.inet_ntoa(struct.pack('=I', addr))


def _is_ipv4_loopback(addr: int) -> bool:
    return _ipv4_text(addr).startswith(_LOOPBACK_V4_PREFIX)


def _is_ipv6_loopback(addr: bytes) -> bool:
    return bytes(addr) in {_IPV6_LOOPBACK, _IPV6_UNSPECIFIED}


class WindowsProcessNetworkCounter:
    """TCP ESTATS bytes for a process tree, with NIC totals as a sanity check.

    Closed connections keep their last byte count so short HTTP requests are
    not lost when the socket disappears between samples.
    """

    def __init__(self, pid: int):
        self._pid = pid
        self._iphlpapi = ctypes.WinDLL('iphlpapi')
        self._enabled: set[tuple] = set()
        self._live_bytes: dict[tuple, int] = {}
        self._closed_bytes = 0
        self._closed_https_bytes = 0
        self._enable_failures = 0
        self._enable_attempts = 0
        self._lock = threading.Lock()

    def snapshot(self) -> NetworkSnapshot:
        with self._lock:
            return self._snapshot_locked()

    def _snapshot_locked(self) -> NetworkSnapshot:
        pids = process_tree_pids(self._pid)
        tcp_bytes, https_bytes, tcp_conns = self._tcp_bytes(pids)
        udp_endpoints = self._udp_endpoints(pids)
        nic_bytes = nic_bytes_total()
        estats_works = self._enable_attempts == 0 or (
            self._enable_failures < self._enable_attempts
        )
        if tcp_bytes > 0 and estats_works:
            app_bytes, source = tcp_bytes, 'tcp'
        else:
            app_bytes, source = nic_bytes, 'nic'
        return NetworkSnapshot(
            app_bytes=app_bytes,
            tcp_bytes=tcp_bytes,
            https_bytes=https_bytes,
            nic_bytes=nic_bytes,
            tcp_connections=tcp_conns,
            udp_endpoints=udp_endpoints,
            source=source,
        )

    def wait_until_settled(self, origin_nic_bytes: int, **kwargs) -> SettleResult:
        """Settle on NIC rate while polling ESTATS so short-lived sockets are kept."""

        def read_bytes() -> int:
            self.snapshot()
            return max(0, nic_bytes_total() - origin_nic_bytes)

        return wait_until_settled(read_bytes, source='nic', **kwargs)

    def _tcp_bytes(self, pids: set[int]) -> tuple[int, int, int]:
        seen: set[tuple] = set()
        connections = 0
        for row in self._tcp_rows_v4():
            if row.dwOwningPid not in pids:
                continue
            if _is_ipv4_loopback(row.dwLocalAddr) or _is_ipv4_loopback(row.dwRemoteAddr):
                continue
            key = ('tcp4', row.dwLocalAddr, row.dwLocalPort, row.dwRemoteAddr, row.dwRemotePort)
            seen.add(key)
            connections += 1
            self._live_bytes[key] = max(self._live_bytes.get(key, 0), self._estats_v4(row))
        for row in self._tcp_rows_v6():
            if row.dwOwningPid not in pids:
                continue
            if _is_ipv6_loopback(row.ucLocalAddr) or _is_ipv6_loopback(row.ucRemoteAddr):
                continue
            key = (
                'tcp6', bytes(row.ucLocalAddr), row.dwLocalPort,
                bytes(row.ucRemoteAddr), row.dwRemotePort,
            )
            seen.add(key)
            connections += 1
            self._live_bytes[key] = max(self._live_bytes.get(key, 0), self._estats_v6(row))
        for key in list(self._live_bytes):
            if key not in seen:
                closed = self._live_bytes.pop(key)
                self._closed_bytes += closed
                if is_https_remote_port(key[-1]):
                    self._closed_https_bytes += closed
        live_https = sum(
            value for key, value in self._live_bytes.items()
            if is_https_remote_port(key[-1])
        )
        tcp_bytes = self._closed_bytes + sum(self._live_bytes.values())
        https_bytes = self._closed_https_bytes + live_https
        return tcp_bytes, https_bytes, connections

    def _udp_endpoints(self, pids: set[int]) -> int:
        count = 0
        for row in self._udp_rows_v4():
            if row.dwOwningPid in pids and not _is_ipv4_loopback(row.dwLocalAddr):
                count += 1
        return count

    def _estats_v4(self, row: _MIB_TCPROW_OWNER_PID) -> int:
        tcp_row = _MIB_TCPROW(
            row.dwState, row.dwLocalAddr, row.dwLocalPort,
            row.dwRemoteAddr, row.dwRemotePort,
        )
        key = ('tcp4', row.dwLocalAddr, row.dwLocalPort, row.dwRemoteAddr, row.dwRemotePort)
        return self._read_estats(key, tcp_row, ipv6=False)

    def _estats_v6(self, row: _MIB_TCP6ROW_OWNER_PID) -> int:
        tcp_row = _MIB_TCP6ROW(
            row.dwState, row.ucLocalAddr, row.dwLocalScopeId, row.dwLocalPort,
            row.ucRemoteAddr, row.dwRemoteScopeId, row.dwRemotePort,
        )
        key = (
            'tcp6', bytes(row.ucLocalAddr), row.dwLocalPort,
            bytes(row.ucRemoteAddr), row.dwRemotePort,
        )
        return self._read_estats(key, tcp_row, ipv6=True)

    def _read_estats(self, key: tuple, tcp_row, *, ipv6: bool) -> int:
        if key not in self._enabled:
            if not self._enable_estats(tcp_row, ipv6=ipv6):
                return 0
            self._enabled.add(key)
        rod = _TCP_ESTATS_DATA_ROD_v0()
        getter = (
            self._iphlpapi.GetPerTcp6ConnectionEStats
            if ipv6 else self._iphlpapi.GetPerTcpConnectionEStats
        )
        status = getter(
            ctypes.byref(tcp_row),
            _TCP_ESTATS_DATA,
            None, 0, 0,
            None, 0, 0,
            ctypes.byref(rod), 0, ctypes.sizeof(rod),
        )
        if status != _NO_ERROR:
            return 0
        return int(rod.DataBytesIn + rod.DataBytesOut)

    def _enable_estats(self, tcp_row, *, ipv6: bool) -> bool:
        rw = _TCP_ESTATS_DATA_RW_v0(1)
        setter = (
            self._iphlpapi.SetPerTcp6ConnectionEStats
            if ipv6 else self._iphlpapi.SetPerTcpConnectionEStats
        )
        status = setter(
            ctypes.byref(tcp_row),
            _TCP_ESTATS_DATA,
            ctypes.byref(rw),
            0,
            ctypes.sizeof(rw),
            0,
        )
        self._enable_attempts += 1
        if status != _NO_ERROR:
            self._enable_failures += 1
            LOG.debug('SetPerTcpConnectionEStats failed status=%s ipv6=%s', status, ipv6)
            return False
        return True

    def _tcp_rows_v4(self) -> list[_MIB_TCPROW_OWNER_PID]:
        return self._owner_pid_rows(
            self._iphlpapi.GetExtendedTcpTable,
            _MIB_TCPROW_OWNER_PID,
            _AF_INET,
            _TCP_TABLE_OWNER_PID_ALL,
        )

    def _tcp_rows_v6(self) -> list[_MIB_TCP6ROW_OWNER_PID]:
        return self._owner_pid_rows(
            self._iphlpapi.GetExtendedTcpTable,
            _MIB_TCP6ROW_OWNER_PID,
            _AF_INET6,
            _TCP_TABLE_OWNER_PID_ALL,
        )

    def _udp_rows_v4(self) -> list[_MIB_UDPROW_OWNER_PID]:
        return self._owner_pid_rows(
            self._iphlpapi.GetExtendedUdpTable,
            _MIB_UDPROW_OWNER_PID,
            _AF_INET,
            _UDP_TABLE_OWNER_PID,
        )

    def _owner_pid_rows(self, getter, row_cls, family: int, table_class: int):
        size = wintypes.DWORD(0)
        getter(None, ctypes.byref(size), False, family, table_class, 0)
        if size.value == 0:
            return []
        buf = ctypes.create_string_buffer(size.value)
        status = getter(buf, ctypes.byref(size), False, family, table_class, 0)
        if status != _NO_ERROR:
            return []
        count = struct.unpack_from('I', buf, 0)[0]
        offset = ctypes.sizeof(wintypes.DWORD)
        padding = (ctypes.alignment(row_cls) - (offset % ctypes.alignment(row_cls))) % ctypes.alignment(row_cls)
        offset += padding
        rows = []
        row_size = ctypes.sizeof(row_cls)
        for index in range(count):
            start = offset + index * row_size
            rows.append(row_cls.from_buffer_copy(buf.raw[start:start + row_size]))
        return rows


def measure_screen_data_usage(
    pid: int,
    action: Callable[[], object],
    **settle_kwargs,
) -> tuple[object, SettleResult]:
    """Run a UI action, then wait until traffic settles. Returns (action result, settle)."""
    counter = WindowsProcessNetworkCounter(pid)
    before = counter.snapshot()
    stop = threading.Event()

    def poll() -> None:
        while not stop.wait(0.5):
            counter.snapshot()

    sampler = threading.Thread(target=poll, daemon=True)
    sampler.start()
    try:
        result = action()
        settle = counter.wait_until_settled(before.nic_bytes, **settle_kwargs)
    finally:
        stop.set()
        sampler.join(timeout=2)
    end = counter.snapshot()
    tcp_delta = max(0, end.tcp_bytes - before.tcp_bytes)
    https_delta = max(0, end.https_bytes - before.https_bytes)
    nic_delta = max(0, end.nic_bytes - before.nic_bytes)
    udp_delta = max(0, nic_delta - tcp_delta)
    if tcp_delta >= nic_delta * 0.5 and tcp_delta > 0:
        incremental, source = tcp_delta, 'tcp'
        udp_delta = 0
    else:
        incremental, source = nic_delta, 'nic'
        if nic_delta > 0:
            LOG.info(
                'Using NIC delta (tcp=%s nic=%s) on dedicated Windows agent',
                tcp_delta, nic_delta,
            )
    combined = SettleResult(
        incremental_bytes=incremental,
        elapsed_sec=settle.elapsed_sec,
        hit_cap=settle.hit_cap,
        sample_count=settle.sample_count,
        source=source,
        https_bytes=https_delta,
        udp_bytes=udp_delta,
    )
    LOG.info(
        'data usage: %.3f MB in %.1fs source=%s hit_cap=%s tcp=%s https=%s udp=%s nic=%s',
        combined.incremental_mb, combined.elapsed_sec, combined.source,
        combined.hit_cap, tcp_delta, https_delta, udp_delta, nic_delta,
    )
    return result, combined
