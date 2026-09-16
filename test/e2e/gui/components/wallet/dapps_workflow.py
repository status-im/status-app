import allure

import configs
import driver
from gui.elements.button import Button
from gui.elements.object import QObject, set_text_property_on_object
from gui.objects_map import dapps_names


class DappsWorkflow:

    def __init__(self):
        self._connect_dapp_button = Button(dapps_names.connect_dapp_button)
        self._wallet_connect_button = QObject(dapps_names.btn_wallet_connect)
        self._wc_uri_input = QObject(dapps_names.wc_uri_input)
        self._connect_primary_button = Button(dapps_names.connect_dapp_primary_button)
        self._sign_button = Button(dapps_names.dapp_sign_button)

    @allure.step('Open WalletConnect connect dApp flow')
    def open_connect_dapp_flow(self, dapps_combo: QObject) -> 'DappsWorkflow':
        if not self._connect_dapp_button.is_visible:
            dapps_combo.click()
            self._connect_dapp_button.wait_until_appears()
        self._connect_dapp_button.click()

        self._wallet_connect_button.wait_until_appears()
        self._wallet_connect_button.click()
        self._wc_uri_input.wait_until_appears()
        return self

    @allure.step('Pair WalletConnect URI')
    def pair_with_uri(
            self,
            uri: str,
            timeout_msec: int = configs.timeouts.APP_LOAD_TIMEOUT_MSEC,
    ) -> 'DappsWorkflow':
        set_text_property_on_object(self._wc_uri_input.object.edit, uri.strip(), timeout_msec)
        self._connect_primary_button.wait_until_appears(timeout_msec)
        self._connect_primary_button.wait_until_enabled(timeout_msec)
        return self

    @allure.step('Approve WalletConnect connection and close popup')
    def approve_connection_and_close(
            self,
            timeout_msec: int = configs.timeouts.APP_LOAD_TIMEOUT_MSEC,
    ) -> 'DappsWorkflow':
        connect_button_text = str(self._connect_primary_button.object.text)
        self._connect_primary_button.wait_until_enabled(timeout_msec)
        self._connect_primary_button.click()

        def _close_ready() -> bool:
            try:
                button = self._connect_primary_button.object
                return (
                    bool(button.visible)
                    and bool(button.enabled)
                    and str(button.text) != connect_button_text
                )
            except (LookupError, RuntimeError, AttributeError):
                return False

        assert driver.waitFor(_close_ready, timeout_msec), (
            'Close button on connected dApp popup did not appear'
        )
        self._connect_primary_button.click()
        self._connect_primary_button.wait_until_hidden(timeout_msec)
        return self

    @allure.step('Approve WalletConnect sign request')
    def approve_sign_request(self, timeout_msec: int = configs.timeouts.APP_LOAD_TIMEOUT_MSEC) -> 'DappsWorkflow':
        self._sign_button.wait_until_appears(timeout_msec)
        self._sign_button.click()
        return self
