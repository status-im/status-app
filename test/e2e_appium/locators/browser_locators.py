from locators.base_locators import BaseLocators


class BrowserLocators(BaseLocators):
    """Locators for the in-app browser address field and download pill.

    QML: ui/app/AppLayouts/Browser/controls/BrowserAddressField.qml,
    controls/DownloadPill.qml, and the DownloadRecordMenu in BrowserLayout.qml.
    The download pill has no file name in the accessibility tree, so these
    locators cannot tell two downloads apart.
    """

    ADDRESS_FIELD = BaseLocators.tid("browserAddressField")
    DOWNLOAD_OPTIONS = BaseLocators.tid("downloadPillOptionsButton")
    DOWNLOAD_PILL = BaseLocators.xpath(f"{DOWNLOAD_OPTIONS[1]}/..")
    DOWNLOAD_MENU = BaseLocators.tid("DownloadRecordMenu")
    COMPLETED_FILE_ACTION = BaseLocators.xpath(
        "//*[contains(@resource-id, 'DownloadRecordMenu')]"
        "//*[@content-desc='Share file' and @enabled='true']"
    )
