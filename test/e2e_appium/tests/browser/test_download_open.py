"""Browser downloads open in the Android app that handles their file type."""

import os
from urllib.parse import urlsplit

import pytest

from pages.browser_page import BrowserPage
from support.multi_device_helpers import StepMixin
from support.platform import is_android

FIXTURE_BASE_URL = os.getenv("E2E_DOWNLOAD_FIXTURE_BASE_URL", "").rstrip("/")
DOCUMENTS_UI = {"com.google.android.documentsui", "com.android.documentsui"}
# Android opens Settings > Install unknown apps first when Status may not install apps yet.
APK_INSTALL_FLOW = {
    "com.google.android.packageinstaller",
    "com.android.packageinstaller",
    "com.android.settings",
}


@pytest.mark.skipif(
    not FIXTURE_BASE_URL,
    reason="Set E2E_DOWNLOAD_FIXTURE_BASE_URL to device-trusted HTTPS APK/PDF fixtures",
)
@pytest.mark.e2e
@pytest.mark.portrait
@pytest.mark.device_count(1)
class TestDownloadOpen(StepMixin):
    """Browser: tapping a completed download opens the file.

    One Android device with a fresh browser session. Files come from
    E2E_DOWNLOAD_FIXTURE_BASE_URL, an HTTPS host the device trusts.
    """

    @pytest.mark.spec("SC-BRW-13")
    @pytest.mark.parametrize("extension", ["apk", "pdf"])
    async def test_completed_download_opens_handler(self, extension):
        """Download a file, tap its download pill, and check which app opens.

        An APK opens Package installer and a PDF opens a viewer. Files
        (DocumentsUI) showing the Download folder fails both cases.
        """
        if not is_android(self.driver):
            pytest.skip("Android download handlers only")
        parsed = urlsplit(FIXTURE_BASE_URL)
        assert parsed.scheme == "https" and parsed.netloc, (
            "E2E_DOWNLOAD_FIXTURE_BASE_URL must be HTTPS trusted by the device"
        )
        browser = BrowserPage(self.driver)

        async with self.step(self.device, "Open the browser"):
            browser.open_browser()
            status_package = browser.foreground_package()

        try:
            async with self.step(self.device, f"Download the {extension} fixture"):
                browser.load_url(f"{FIXTURE_BASE_URL}/status-fixture.{extension}")
                browser.wait_for_completed_download()

            async with self.step(self.device, f"Open the downloaded {extension}"):
                browser.open_completed_download()
                package = browser.wait_for_external_package(status_package)
                assert package not in DOCUMENTS_UI, (
                    f"Downloaded {extension} opened DocumentsUI ({package}), not its handler"
                )
                # A PDF opens in its viewer, or in Android's "Open with" list when
                # several PDF apps are installed and none is the default.
                if extension == "apk":
                    assert package in APK_INSTALL_FLOW, f"Expected the install flow, got {package!r}"
        finally:
            async with self.step(self.device, "Return to Status"):
                browser.return_from_external_app(status_package)
