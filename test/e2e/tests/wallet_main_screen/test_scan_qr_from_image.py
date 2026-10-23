import pytest
from allure_commons._allure import step

import configs
import driver
from constants.wallet import WalletAddress
from gui.components.wallet.send_popup import SendPopup
from scripts.utils.system_path import SystemPath


@pytest.mark.wallet
def test_scan_wallet_address_from_image(main_screen):
    address = WalletAddress.RECEIVER_ADDRESS.value
    image_path = SystemPath(configs.testpath.TEST_FILES / "wallet_receiver_address_qr.png")

    with step('Scan the address QR from an image'):
        main_screen.left_panel.open_qr_scanner().upload_image(image_path)

    with step('Send opens for that address'):
        send_popup = SendPopup().wait_until_appears()
        assert driver.waitFor(
            lambda: send_popup.selected_recipient_address.lower() == address.lower(),
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        )
