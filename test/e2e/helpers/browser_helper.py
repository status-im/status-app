import functools
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class _QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, fmt, *args):
        return


class LocalBrowserPages:
    """Serves static pages for in-app browser e2e."""

    def __init__(self, directory: Path):
        handler = functools.partial(_QuietHandler, directory=str(directory))
        self._httpd = ThreadingHTTPServer(('127.0.0.1', 0), handler)
        self._thread = threading.Thread(target=self._httpd.serve_forever, daemon=True)

    @property
    def origin(self) -> str:
        host, port = self._httpd.server_address
        return f'http://{host}:{port}'

    def start(self) -> 'LocalBrowserPages':
        self._thread.start()
        return self

    def stop(self) -> None:
        self._httpd.shutdown()
        self._httpd.server_close()
