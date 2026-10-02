import pytest
from allure_commons._allure import step

import configs
import driver
from constants import RandomUser, UserAccount
from constants.messaging import Messaging
from constants.wallet import WalletTokenSymbols
from gui.main_window import MainWindow
from helpers.multiple_instances_helper import (
    add_mutual_contact_via_activity_center,
    authorize_user_in_aut,
    switch_to_aut,
)
from scripts.utils.generators import random_text_message


@pytest.mark.critical
def test_request_payment_in_chat(multiple_instances):
    requester: UserAccount = RandomUser()
    payer: UserAccount = RandomUser()
    main_window = MainWindow()
    message_text = random_text_message()
    amount = Messaging.PAYMENT_REQUEST_AMOUNT.value
    symbol = WalletTokenSymbols.ETH.value

    with (multiple_instances(user_data=None) as aut_requester,
          multiple_instances(user_data=None) as aut_payer):
        with step(f'Launch instances for {requester.name} and {payer.name}'):
            for aut, account in zip([aut_requester, aut_payer], [requester, payer]):
                authorize_user_in_aut(aut, main_window, account)

        add_mutual_contact_via_activity_center(
            aut_requester,
            aut_payer,
            main_window,
            requester,
            payer,
        )

        with step(f'{requester.name} requests {amount} {symbol} in chat with {payer.name}'):
            switch_to_aut(aut_requester, main_window)
            messages_screen = main_window.left_panel.open_messages_screen()
            messages_screen.left_panel.click_chat_by_name(payer.name)
            receiver_address = (
                messages_screen.group_chat.open_payment_request_modal().add_to_message(amount, symbol)
            )
            preview = messages_screen.group_chat.wait_for_payment_request_preview()
            assert driver.waitFor(
                lambda: str(preview.object.symbol) == symbol,
                configs.timeouts.ROUTES_TIMEOUT_MSEC,
            ), f'Payment request preview symbol is not {symbol}: {preview.object.symbol!r}'
            assert driver.waitFor(
                lambda: str(preview.object.amount) == amount,
                configs.timeouts.ROUTES_TIMEOUT_MSEC,
            ), f'Payment request preview amount is not {amount}: {preview.object.amount!r}'
            messages_screen.group_chat.send_message_to_group_chat(message_text)
            messages_screen.chat.find_message_by_text(message_text, 0)
            main_window.minimize()

        with step(f'{payer.name} sees the payment request and opens Send'):
            switch_to_aut(aut_payer, main_window)
            messages_screen = main_window.left_panel.open_messages_screen()
            chat = messages_screen.left_panel.click_chat_by_name(requester.name)
            chat.find_message_by_text(message_text, 0)
            card = chat.payment_request_card()
            assert str(card.object.symbol) == symbol
            assert str(card.object.amount) == amount
            assert str(card.object.address).lower() == receiver_address.lower()

            send_modal = chat.open_send_modal_from_payment_request()
            assert send_modal.selected_recipient_address.lower() == receiver_address.lower()
            assert driver.waitFor(
                lambda: send_modal.send_modal_amount_field.text == amount,
                configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
            ), f'Send amount is not {amount}: {send_modal.send_modal_amount_field.text!r}'
            send_modal.close_without_signing()
