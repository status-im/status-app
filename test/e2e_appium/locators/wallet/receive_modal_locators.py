from ..base_locators import BaseLocators


class ReceiveModalLocators(BaseLocators):
    """Locators for the Receive Modal (QR code / address popup)."""

    # Modal container - objectName in QML is "receiveModal" (lowercase 'm')
    MODAL_CONTAINER = BaseLocators.resource_id_contains("receiveModal")

    # QR code image - uses Accessible.name which maps to content-desc on Android
    QR_CODE_IMAGE = BaseLocators.content_desc_contains("QR code for wallet address")

    # Address text - Accessible.name contains the wallet address (0x... or 0×...)
    # Note: Font may render 'x' as multiplication sign '×' (U+00D7)
    ADDRESS_TEXT = BaseLocators.xpath(
        "//*[starts-with(@content-desc, '0x') or starts-with(@content-desc, '0×')]"
    )

    # Copy button - uses Accessible.name
    COPY_BUTTON = BaseLocators.content_desc_contains("Copy address")
