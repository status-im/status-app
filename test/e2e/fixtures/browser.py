import pytest

import configs
from helpers.browser_helper import LocalBrowserPages

_BROWSER_PAGES_DIR = configs.testpath.ROOT / 'scripts' / 'browser_pages'


@pytest.fixture
def browser_pages():
    server = LocalBrowserPages(_BROWSER_PAGES_DIR).start()
    yield server
    server.stop()
