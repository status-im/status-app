import allure

import configs.timeouts
import constants.wallet
import driver
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
        self._pay_holding_selector = QObject(names.swapModalPayHoldingSelector)
        self._receive_holding_selector = QObject(names.swapModalReceiveHoldingSelector)
        self._pay_dropdown = QObject(names.swapModalPayDropdown)
        self._receive_dropdown = QObject(names.swapModalReceiveDropdown)
        self._pay_token_label = TextLabel(names.swapModalPayTokenSelectorText)
        self._receive_token_label = TextLabel(names.swapModalReceiveTokenSelectorText)
        self._pay_assets_panel = QObject(names.swapModalPayAssetsPanel)
        self._receive_assets_panel = QObject(names.swapModalReceiveAssetsPanel)
        self._pay_search_box = TextEdit(names.swapModalPaySearchBox)
        self._receive_search_box = TextEdit(names.swapModalReceiveSearchBox)
        self._pay_chain_chip = QObject(names.swapModalPayChainChip)
        self._receive_chain_chip = QObject(names.swapModalReceiveChainChip)
        self._pay_asset_row = QObject(names.swapModalPayAssetDelegate)
        self._receive_asset_row = QObject(names.swapModalReceiveAssetDelegate)

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
        expected = amount.replace(',', '.')
        self._amount_field.clear()
        self._amount_field.type_text(expected)
        assert driver.wait_until(
            lambda: self._amount_field.text.replace(',', '.') == expected,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), (
            f'Type text failed, value in field: "{self._amount_field.text}", '
            f'expected: {expected}'
        )
        return self

    def _token_button(self, side: str) -> Button:
        return self._pay_token_button if side == 'pay' else self._receive_token_button

    def _holding_selector(self, side: str) -> QObject:
        return self._pay_holding_selector if side == 'pay' else self._receive_holding_selector

    def _dropdown(self, side: str) -> QObject:
        return self._pay_dropdown if side == 'pay' else self._receive_dropdown

    def _open_token_picker(self, side: str):
        panel = self._assets_panel(side)
        self._token_button(side).click()
        if panel.is_visible:
            return
        self._dropdown(side).object.open()
        panel.wait_until_appears()

    def _assets_panel(self, side: str) -> QObject:
        return self._pay_assets_panel if side == 'pay' else self._receive_assets_panel

    def _search_box(self, side: str) -> TextEdit:
        return self._pay_search_box if side == 'pay' else self._receive_search_box

    def _chain_chip(self, side: str) -> QObject:
        return self._pay_chain_chip if side == 'pay' else self._receive_chain_chip

    def _token_label(self, side: str) -> TextLabel:
        return self._pay_token_label if side == 'pay' else self._receive_token_label

    def _asset_row(self, side: str) -> QObject:
        return self._pay_asset_row if side == 'pay' else self._receive_asset_row

    def _select_network(self, side: str, chain_id: int):
        chip_name = f'chainChip_{chain_id}'
        chip_locator = self._chain_chip(side).real_name
        found = []

        def locate():
            found[:] = [
                chip for chip in driver.find_all(chip_locator)
                if str(getattr(chip, 'objectName', '')) == chip_name
            ]
            return bool(found)

        assert driver.wait_until(locate, configs.timeouts.LOADING_LIST_TIMEOUT_MSEC), (
            f'Network chip {chip_name} was not found on swap {side} picker'
        )
        chip = found[0]

        if not chip.checked:
            QObject(chip).click()
        assert driver.wait_until(
            lambda: bool(chip.checked),
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), (
            f'Network chip {chip_name} did not stay selected on swap {side} picker'
        )

    @allure.step('Select {symbol} on the {side} side')
    def select_token(self, side: str, symbol: str, chain_id: int = None):
        assert side in ('pay', 'receive'), f'Unknown swap side: {side}'
        self._open_token_picker(side)
        if chain_id is not None:
            self._select_network(side, chain_id)
        self._search_box(side).text = symbol
        rows = []

        def selectable_asset_found():
            rows[:] = [
                item for item in driver.find_all(self._asset_row(side).real_name)
                if str(getattr(item, 'symbol', '')) == symbol and item.enabled
            ]
            return bool(rows)

        assert driver.wait_until(
            selectable_asset_found,
            configs.timeouts.LOADING_LIST_TIMEOUT_MSEC,
        ), f'Token {symbol} on chain {chain_id} was not selectable'

        self._select_asset_row(side, rows[0], chain_id)
        self._wait_until_token_selected(side, symbol)
        return self

    def _group_key_for_row(self, row, symbol: str) -> str:
        group_key = str(getattr(row, 'groupKey', '') or '')
        if group_key:
            return group_key
        return constants.wallet.SWAP_TOKEN_GROUP_KEYS.get(symbol, '')

    def _select_asset_row(self, side: str, row, chain_id: int):
        symbol = str(getattr(row, 'symbol', ''))
        group_key = self._group_key_for_row(row, symbol)
        assert group_key, f'Token {symbol} has no groupKey'
        chain = -1 if chain_id is None else int(chain_id)
        self._holding_selector(side).object.selectGroupKey(group_key, chain)

    def _wait_until_token_selected(self, side: str, symbol: str):
        panel = self._assets_panel(side)
        label = self._token_label(side)

        assert driver.wait_until(
            lambda: label.text == symbol and not panel.is_visible,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), (
            f'Token {symbol} was not selected on the {side} side. '
            f'Button text={label.text!r}, picker visible={panel.is_visible}'
        )

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
            seen['quote'] = self._quote_text.text if self._quote_text.is_visible else ''
            if seen['text'].startswith('Approve'):
                return True
            return (
                not seen['error']
                and seen['text'] == expected_text
                and self.sign_interactive
                and bool(seen['quote'])
            )

        assert driver.wait_until(ready, timeout_msec), (
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
            driver.type_text(self.object, '<Escape>')
        self.wait_until_hidden()
        return self
