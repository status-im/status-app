import time

import allure
import typing

import configs.timeouts
import driver
from driver.objects_access import walk_children
from gui.components.wallet.sign_send_popup import SignSendModalPopup
from gui.components.wallet.token_selector_popup import TokenSelectorPopup
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.text_edit import TextEdit
from gui.elements.text_label import TextLabel
from gui.objects_map import names
from helpers.wallet_helper import find_network_option_item


class SendPopup(QObject):

    def __init__(self):
        super().__init__(names.simpleSendModal)
        self.send_modal_header = QObject(names.sendModalHeader)
        self.send_modal_title = TextLabel(names.sendModalTitle)
        self._send_modal_recipient_panel = QObject(names.sendModalRecipientPanel)
        self.send_modal_recipient_delegate = QObject(names.sendModalRecipientViewDelegate)
        self.send_modal_token_selector = Button(names.sendModalTokenSelector)
        self.send_modal_network_filter = QObject(names.sendModalNetworkFilter)
        self.send_modal_network_item = QObject(names.sendModalNetworkSelectorItem)
        self.send_modal_amount_field = TextEdit(names.sendModalAmountField)
        self.send_modal_recipient_field = TextEdit(names.sendModalRecipientField)
        self.send_modal_sign_txn_fees = QObject(names.sendModalSendTransactionFees)
        self.send_modal_review_send_button = Button(names.sendModalReviewSendButton)
        self.send_button = Button(names.send_StatusFlatButton)
        self.tokens_list = QObject(names.statusListView)
        self.asset_list_item = QObject(names.o_TokenBalancePerChainDelegate_template)
        self.ens_address_text_input = TextEdit(names.ens_or_address_text_input)

    @property
    @allure.step('Get selected recipient address')
    def selected_recipient_address(self) -> str:
        return str(self._send_modal_recipient_panel.object.selectedRecipientAddress)

    @allure.step('Get assets or collectibles list')
    def get_assets_or_collectibles_list(self, tab: str) -> typing.List[str]:
        assets_or_collectibles_list = []
        if tab == 'Assets':
            for asset in driver.findAllObjects(self.asset_list_item.real_name):
                assets_or_collectibles_list.append(asset)
        elif tab == 'Collectibles':
            for asset in walk_children(self.tokens_list.object):
                assets_or_collectibles_list.append(asset)
        return assets_or_collectibles_list

    @allure.step('Open token selector')
    def open_token_selector(self):
        self.send_modal_token_selector.click()
        return TokenSelectorPopup().wait_until_appears()

    @allure.step('Select network in network selector')
    def select_network(self, network_name):
        self.send_modal_network_filter.click()
        network_options = driver.findAllObjects(self.send_modal_network_item.real_name)
        assert network_options, 'Network options are not displayed'
        QObject(find_network_option_item(network_name, network_options)).click()
        time.sleep(0.2)
        return self

    @staticmethod
    def _same_address(actual: str, expected: str) -> bool:
        return actual.strip().lower() == expected.strip().lower()

    def _recipient_is_selected(self, address: str) -> bool:
        try:
            return self._same_address(self.selected_recipient_address, address)
        except (LookupError, RuntimeError, AttributeError):
            return False

    @allure.step('Select address from suggestions if available')
    def select_from_suggestions_if_shown(self, address: str):
        """Pick a suggestion whose title or address matches. Named accounts use the address role."""
        try:
            if not self._send_modal_recipient_panel.is_visible:
                return False
            for delegate in driver.findAllObjects(self.send_modal_recipient_delegate.real_name):
                title = str(getattr(delegate, 'title', ''))
                delegate_address = str(getattr(delegate, 'address', ''))
                if self._same_address(title, address) or self._same_address(delegate_address, address):
                    QObject(delegate).click()
                    time.sleep(0.2)
                    return True
        except Exception:
            pass
        return False

    @allure.step('Close send modal without signing')
    def close_without_signing(self):
        driver.type(self.object, '<Escape>')
        self.wait_until_hidden()
        return self

    @allure.step('Open sign and send modal')
    def open_sign_send_modal(self):
        self.send_modal_review_send_button.click()
        return SignSendModalPopup().wait_until_appears()

    def _set_recipient_address(self, address: str, wait_for_field: bool = False):
        if wait_for_field:
            self.ens_address_text_input.wait_until_appears(
                timeout_msec=configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
            )
        self.ens_address_text_input.click()
        self.ens_address_text_input.set_text_property(address)
        driver.waitFor(
            lambda: self._recipient_is_selected(address),
            configs.timeouts.RECIPIENT_VALIDATION_MSEC,
        )
        if not self._recipient_is_selected(address):
            self.select_from_suggestions_if_shown(address)

        assert driver.waitFor(
            lambda: self._recipient_is_selected(address),
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), f'Recipient {address} was not selected'

    def _parse_amount(self, raw: str) -> float:
        if not raw:
            return 0.0

        for prefix in ('Max.', 'Max:'):
            if prefix in raw:
                raw = raw.split(prefix, 1)[-1]

        number = raw.strip().split()[0].replace(',', '').replace('\xa0', '')
        try:
            return float(number)
        except (ValueError, IndexError):
            return 0.0

    def _max_send_balance(self) -> float:
        try:
            button = driver.waitForObjectExists(names.sendModalMaxButton, 200)
        except (LookupError, RuntimeError):
            return 0.0

        formatted_value = getattr(button, 'formattedValue', None)
        if formatted_value not in (None, ''):
            return self._parse_amount(str(formatted_value))

        return self._parse_amount(str(getattr(button, 'text', '')))

    @allure.step('Wait until send modal token balance is ready')
    def wait_until_send_balance_ready(
            self,
            timeout_msec: int = configs.timeouts.ROUTES_TIMEOUT_MSEC,
    ):
        assert driver.waitFor(lambda: self._max_send_balance() > 0, timeout_msec), (
            f'Send modal still shows zero max balance, got: {self._max_send_balance()!r}'
        )
        return self

    def _review_send_enabled(self) -> bool:
        try:
            button = driver.waitForObjectExists(names.sendModalReviewSendButton, 200)
        except (LookupError, RuntimeError):
            return False
        return button.enabled

    @allure.step('Wait until route estimation completes and Review Send is enabled')
    def wait_for_review_send_ready(
            self,
            timeout_msec: int = configs.timeouts.ROUTES_TIMEOUT_MSEC,
    ):
        self.send_modal_sign_txn_fees.wait_until_appears(timeout_msec=timeout_msec)

        send_modal_footer = {
            'container': names.statusDesktop_mainWindow_overlay,
            'objectName': 'sendModalFooter',
            'visible': True,
        }

        def review_send_ready():
            try:
                footer = driver.findObject(send_modal_footer)
                if getattr(footer, 'error', False):
                    return False
            except Exception:
                pass
            return self._review_send_enabled()

        assert driver.waitFor(review_send_ready, timeout_msec), (
            'Review Send is not enabled (insufficient funds, fees loading, or router error)'
        )
        return self

    @allure.step('Send {2} {3} to {1}')
    def sign_and_send(self, address: str, amount: str, asset: str, collectible_collection: str = ''):
        token_selector = self.open_token_selector()

        if asset:
            token_selector.select_asset_from_list(asset_name=asset)
            self.wait_until_send_balance_ready()
            self.send_modal_amount_field.text = amount
            time.sleep(1)
            self._set_recipient_address(address)
        else:
            search_view = token_selector.open_collectibles_search_view()
            if collectible_collection:
                search_view.select_collectible_from_collection(collectible_collection)
            else:
                search_view.select_random_collectible()
            self._set_recipient_address(
                address,
                wait_for_field=True,
            )

        self.wait_for_review_send_ready()

        self.open_sign_send_modal().sign_send_modal_reject_button.click()
        sign_send_modal = self.open_sign_send_modal()
        sign_send_modal.sign_send_modal_sign_button.click()
