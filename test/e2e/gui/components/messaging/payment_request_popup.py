import allure

import configs
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.text_edit import TextEdit
from gui.objects_map import messaging_names


class PaymentRequestPopup(QObject):

    def __init__(self):
        super().__init__(messaging_names.paymentRequestAmountField)
        self._amount_field = TextEdit(messaging_names.paymentRequestAmountField)
        self._account_selector = QObject(messaging_names.paymentRequestAccountSelector)
        self._add_button = Button(messaging_names.paymentRequestAddButton)

    @allure.step('Wait until appears {0}')
    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._amount_field.wait_until_appears(timeout_msec)
        return self

    @allure.step('Add {1} to the message')
    def add_to_message(self, amount: str, symbol: str | None = None) -> str:
        self._amount_field.text = amount
        self._add_button.wait_until_enabled(configs.timeouts.ROUTES_TIMEOUT_MSEC)
        receiver_address = str(self._account_selector.object.currentAccountAddress)
        self._add_button.click()
        self._amount_field.wait_until_hidden()
        return receiver_address
