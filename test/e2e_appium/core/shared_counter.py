"""File-based shared counter for cross-process coordination with pytest-xdist."""

import fcntl
import os
import tempfile
from pathlib import Path
from typing import Optional


class FileBasedCounter:
    """Thread-safe file-based counter that works across pytest-xdist workers.
    
    Uses file locking to ensure atomic read-modify-write operations.
    Compatible with execnet/xdist serialization since only the file path is shared.
    """

    def __init__(self, file_path: Path, initial_value: int = 0):
        """Initialize counter with a file path.
        
        Args:
            file_path: Path to the counter file
            initial_value: Initial value if file doesn't exist
        """
        self._file_path = Path(file_path)
        self._lock_path = self._file_path.with_suffix(self._file_path.suffix + ".lock")
        self._initial_value = initial_value
        
        # Ensure parent directory exists
        self._file_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Initialize file if it doesn't exist
        if not self._file_path.exists():
            self._file_path.write_text(str(initial_value))

    @property
    def value(self) -> int:
        """Read current counter value."""
        try:
            with open(self._file_path, "r") as f:
                fcntl.flock(f.fileno(), fcntl.LOCK_SH)
                try:
                    content = f.read().strip()
                    return int(content) if content else self._initial_value
                finally:
                    fcntl.flock(f.fileno(), fcntl.LOCK_UN)
        except (ValueError, FileNotFoundError):
            return self._initial_value

    @value.setter
    def value(self, new_value: int):
        """Set counter value (atomic write with lock)."""
        with open(self._file_path, "r+") as f:
            fcntl.flock(f.fileno(), fcntl.LOCK_EX)
            try:
                f.seek(0)
                f.write(str(int(new_value)))
                f.truncate()
                f.flush()
                os.fsync(f.fileno())
            finally:
                fcntl.flock(f.fileno(), fcntl.LOCK_UN)

    def get_lock(self):
        """Return a context manager for exclusive file locking.
        
        This mimics the multiprocessing.Value.get_lock() interface.
        The lock provides access to read/write methods that use the same file handle.
        """
        return _FileLock(self._file_path, self._initial_value)

    def __iadd__(self, other: int):
        """In-place addition: counter += value.
        
        Note: This acquires its own lock. For better performance when already locked,
        use the lock context manager's add() method instead.
        """
        with self.get_lock() as lock:
            current = lock.get_value()
            lock.set_value(current + other)
        return self

    def __isub__(self, other: int):
        """In-place subtraction: counter -= value.
        
        Note: This acquires its own lock. For better performance when already locked,
        use the lock context manager's subtract() method instead.
        """
        with self.get_lock() as lock:
            current = lock.get_value()
            lock.set_value(current - other)
        return self


class _FileLock:
    """Context manager for file-based locking with value access."""

    def __init__(self, file_path: Path, initial_value: int):
        self._file_path = file_path
        self._initial_value = initial_value
        self._file = None

    def __enter__(self):
        self._file = open(self._file_path, "r+")
        fcntl.flock(self._file.fileno(), fcntl.LOCK_EX)
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self._file:
            fcntl.flock(self._file.fileno(), fcntl.LOCK_UN)
            self._file.close()
            self._file = None

    def get_value(self) -> int:
        """Read value using the locked file handle."""
        if not self._file:
            raise RuntimeError("Lock not held")
        self._file.seek(0)
        content = self._file.read().strip()
        return int(content) if content else self._initial_value

    def set_value(self, new_value: int):
        """Write value using the locked file handle."""
        if not self._file:
            raise RuntimeError("Lock not held")
        self._file.seek(0)
        self._file.write(str(int(new_value)))
        self._file.truncate()
        self._file.flush()
        os.fsync(self._file.fileno())


def create_shared_counter(base_dir: Optional[Path] = None, counter_name: str = "bs_pending_counter") -> FileBasedCounter:
    """Create a shared counter in a directory accessible to all workers.
    
    Args:
        base_dir: Base directory for counter file (defaults to temp directory)
        counter_name: Name of the counter file
        
    Returns:
        FileBasedCounter instance
    """
    if base_dir is None:
        base_dir = Path(tempfile.gettempdir()) / "pytest_xdist_shared"
    else:
        base_dir = Path(base_dir)
    
    base_dir.mkdir(parents=True, exist_ok=True)
    counter_path = base_dir / f"{counter_name}.txt"
    return FileBasedCounter(counter_path, initial_value=0)

