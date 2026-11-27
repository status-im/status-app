"""Files handed to Status by macOS "Open With" open in browser Tabs."""
import pytest

from configs.system import get_platform
from gui.screens.browser import BrowserScreen
from helpers.open_with_helper import open_with_status, sample_file

pytestmark = [
    pytest.mark.browser,
    pytest.mark.skipif(get_platform() != 'Darwin', reason='"Open With" through LaunchServices'),
]


def test_open_with_pdf_opens_a_tab(main_screen, tmp_path):
    pdf = sample_file(tmp_path, 'pdf')

    open_with_status(pdf)

    BrowserScreen().wait_for_opened_file(pdf.name)


@pytest.mark.parametrize('extension', ['png', 'txt', 'json', 'mp3', 'webm'])
def test_open_with_supported_format_opens_a_tab(main_screen, tmp_path, extension):
    file = sample_file(tmp_path, extension)

    open_with_status(file)

    BrowserScreen().wait_for_opened_file(file.name)


def test_open_with_unsupported_format_says_it_could_not_open(main_screen, tmp_path):
    archive = sample_file(tmp_path, 'zip')

    open_with_status(archive)

    BrowserScreen().wait_for_open_failed(archive.name)
