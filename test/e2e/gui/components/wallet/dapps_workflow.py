import allure

import configs
import driver
from driver.objects_access import find_descendant_by_object_name
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import dapps_names
from gui.objects_map.wallet_names import mainWindow_RightTabView


def _get_wallet_dapps_anchor():
    wallet_tab = driver.waitForObject(
        mainWindow_RightTabView,
        configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
    )
    content_item = find_descendant_by_object_name(wallet_tab, 'dappsContentItem')
    if content_item is not None:
        return content_item
    raise TimeoutError('Wallet dApps combobox not found in RightTabView')


class DappsWorkflow:

    def __init__(self):
        self._connect_dapp_button = Button(dapps_names.connect_dapp_button)
        self._wallet_connect_button = QObject(dapps_names.btn_wallet_connect)
        self._wc_uri_input = QObject(dapps_names.wc_uri_input)
        self._connect_primary_button = Button(dapps_names.connect_dapp_primary_button)
        self._sign_button = Button(dapps_names.dapp_sign_button)

    @allure.step('Open WalletConnect connect dApp flow')
    def open_connect_dapp_flow(self) -> 'DappsWorkflow':
        if not self._connect_dapp_button.is_visible:
            driver.mouseClick(_get_wallet_dapps_anchor())
            self._connect_dapp_button.wait_until_appears()
        self._connect_dapp_button.click()

        self._wallet_connect_button.wait_until_appears()
        self._wallet_connect_button.click()
        QObject(dapps_names.pair_wc_modal).wait_until_appears()
        return self

    @allure.step('Pair WalletConnect URI')
    def pair_with_uri(
            self,
            uri: str,
            timeout_msec: int = configs.timeouts.APP_LOAD_TIMEOUT_MSEC,
    ) -> 'DappsWorkflow':
        QObject(dapps_names.pair_wc_modal).wait_until_appears(timeout_msec)
        self._wc_uri_input.wait_until_appears(timeout_msec)
        self._wc_uri_input.set_text_property(uri.strip())
        # Valid URI triggers pairing automatically; wait for the connect approval modal.
        self._connect_primary_button.wait_until_appears(timeout_msec)
        return self

    @allure.step('Approve WalletConnect connection')
    def approve_connection(self) -> 'DappsWorkflow':
        self._connect_primary_button.click()
        return self

    @allure.step('Approve WalletConnect sign request')
    def approve_sign_request(self, timeout_msec: int = configs.timeouts.APP_LOAD_TIMEOUT_MSEC) -> 'DappsWorkflow':
        QObject(dapps_names.dapps_request_modal).wait_until_appears(timeout_msec)
        self._sign_button.wait_until_appears(timeout_msec)
        self._sign_button.click()
        return self
