import allure

import configs.timeouts
import driver
from constants.networks import WalletNetworkNaming
from gui.components.wallet.sign_swap_popup import SignSwapModalPopup
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.text_edit import TextEdit
from gui.elements.text_label import TextLabel
from gui.objects_map import names


class SwapPopup(QObject):

    def __init__(self):
        super().__init__(names.swapPopup)
        self._close_button = Button(names.swapModalCloseButton)
        self._error_tag = QObject(names.swapModalErrorTag)
        self._quote_text = TextLabel(names.swapModalQuoteText)
        self._sign_button = Button(names.swapModalSignButton)
        self._amount_field = TextEdit(names.swapModalAmountField)
        self._pay_token_button = Button(names.swapModalPayTokenSelectorButton)
        self._receive_token_button = Button(names.swapModalReceiveTokenSelectorButton)
        self._pay_assets_panel = names.swapModalPayAssetsPanel
        self._receive_assets_panel = names.swapModalReceiveAssetsPanel
        self._pay_search_box = names.swapModalPaySearchBox
        self._receive_search_box = names.swapModalReceiveSearchBox
        self._pay_chain_chip = names.swapModalPayChainChip
        self._receive_chain_chip = names.swapModalReceiveChainChip

    @property
    @allure.step('Get swap error tag text')
    def error_text(self) -> str:
        if not self._error_tag.is_visible:
            return ''
        return str(getattr(self._error_tag.object, 'text', ''))

    @property
    @allure.step('Get confirm button text')
    def sign_button_text(self) -> str:
        if not self._sign_button.is_visible:
            return ''
        return self._sign_button.text

    @property
    @allure.step('Check if confirm button accepts a click')
    def sign_interactive(self) -> bool:
        if not self._sign_button.is_visible:
            return False
        return bool(getattr(self._sign_button.object, 'interactive', False))

    @allure.step('Set pay amount')
    def set_pay_amount(self, amount: str):
        self._amount_field.text = amount
        return self

    def _token_button(self, side: str) -> Button:
        return self._pay_token_button if side == 'pay' else self._receive_token_button

    def _assets_panel(self, side: str):
        return self._pay_assets_panel if side == 'pay' else self._receive_assets_panel

    def _search_box(self, side: str):
        return self._pay_search_box if side == 'pay' else self._receive_search_box

    def _chain_chip(self, side: str):
        return self._pay_chain_chip if side == 'pay' else self._receive_chain_chip

    def _select_network(self, side: str, chain_id: int):
        chip_name = f'chainChip_{chain_id}'
        chip_locator = self._chain_chip(side)
        found = {}

        def locate():
            matches = [
                chip for chip in driver.findAllObjects(chip_locator)
                if str(getattr(chip, 'objectName', '')) == chip_name
            ]
            if not matches:
                return False
            found['chip'] = matches[0]
            return True

        assert driver.waitFor(locate, configs.timeouts.LOADING_LIST_TIMEOUT_MSEC), (
            f'Network chip {chip_name} was not found on swap {side} picker. Visible chips: '
            f'{sorted(str(getattr(chip, "objectName", "")) for chip in driver.findAllObjects(chip_locator))}'
        )
        chip = found['chip']

        def selected():
            try:
                return bool(chip.checked)
            except (LookupError, RuntimeError, AttributeError):
                return False

        if not selected():
            QObject(chip).click()
        assert driver.waitFor(selected, configs.timeouts.UI_LOAD_TIMEOUT_MSEC), (
            f'Network chip {chip_name} did not stay selected on swap {side} picker'
        )

    def _asset_rows(self, symbol: str):
        locator = {
            'container': names.statusDesktop_mainWindow_overlay,
            'objectName': f'tokenSelectorAssetDelegate_{symbol}',
            'type': 'TokenSelectorAssetDelegate',
            'visible': True,
        }
        named = driver.findAllObjects(locator)
        if named:
            return named
        return [
            item for item in driver.findAllObjects(names.tokenSelectorAssetDelegate_template)
            if str(getattr(item, 'symbol', '')) == symbol
        ]

    def _wait_for_asset_rows(self, symbol: str, chain_id: int) -> list:
        rows = []

        def ready():
            rows[:] = self._asset_rows(symbol)
            return bool(rows)

        assert driver.waitFor(ready, configs.timeouts.LOADING_LIST_TIMEOUT_MSEC), (
            f'Token {symbol} on chain {chain_id} did not appear in the picker'
        )
        return rows

    @allure.step('Select {symbol} on the {side} side')
    def select_token(self, side: str, symbol: str, chain_id: int = None):
        self._token_button(side).click()
        QObject(self._assets_panel(side)).wait_until_appears()
        if chain_id not in (None, WalletNetworkNaming.LAYER1_ETHEREUM_TESTNET.chain_id):
            self._select_network(side, chain_id)
        TextEdit(self._search_box(side)).text = symbol
        rows = self._wait_for_asset_rows(symbol, chain_id)
        enabled = [item for item in rows if getattr(item, 'enabled', False)]
        assert enabled, f'Token {symbol} on chain {chain_id} was not selectable'
        QObject(enabled[0]).click(x=10, y=10)
        return self

    @allure.step('Wait until the confirm button is ready')
    def wait_until_confirm_ready(
            self,
            expected_text: str,
            timeout_msec: int = configs.timeouts.SWAP_QUOTE_TIMEOUT_MSEC,
    ):
        seen = {}

        def ready():
            seen['error'] = self.error_text
            seen['text'] = self.sign_button_text
            quote = self._quote_text.text if self._quote_text.is_visible else ''
            seen['quote'] = quote
            if seen['text'].startswith('Approve'):
                return True
            return (
                not seen['error']
                and seen['text'] == expected_text
                and self.sign_interactive
                and '≈' in quote
            )

        assert driver.waitFor(ready, timeout_msec), (
            f'Swap modal was not ready to sign {expected_text!r}. Last state: {seen}'
        )
        assert not seen['text'].startswith('Approve'), (
            f'Native token flow opened an approval step: {seen["text"]!r}'
        )
        return self

    @allure.step('Sign {expected_title}')
    def sign(self, expected_title: str):
        self._sign_button.click()
        sign_modal = SignSwapModalPopup().wait_until_appears()
        assert str(getattr(sign_modal.object, 'title', '')) == expected_title
        sign_modal.sign_button.click()
        return self

    @allure.step('Close swap modal')
    def close(self):
        if self._close_button.is_visible:
            self._close_button.click()
        else:
            driver.type(self.object, '<Escape>')
        self.wait_until_hidden()
        return self
