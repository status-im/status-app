import allure
import time

import driver
from gui.components.wallet.swap_popup import SwapPopup
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.objects_map import names


class MarketScreen(QObject):

    def __init__(self):
        # TODO: Add support for Market screen (https://github.com/status-im/status-app/issues/18235)
        super().__init__(names.marketScreen)

        self.tokens_list = QObject(names.marketScreenTokensList)
        self.swap_button = QObject(names.marketScreenSwapButton)
        self.header = Button(names.marketScreenHeading)
        self.token = QObject(names.marketScreenToken)


    @allure.step('Open Swap modal from Market tab')
    def open_swap_modal(self):
        self.swap_button.click()
        return SwapPopup().wait_until_appears()

    @allure.step('Get list of tokens')
    def get_tokens_list(self, timeout_sec: int = 5):
        started_at = time.monotonic()
        tokens = []
        
        while time.monotonic() - started_at < timeout_sec:
            current_tokens = driver.findAllObjects(self.token.real_name)
            if len(current_tokens) > len(tokens):
                tokens = current_tokens
            time.sleep(0.5)
        return tokens

