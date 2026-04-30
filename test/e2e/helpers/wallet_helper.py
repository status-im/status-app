from allure_commons._allure import step

from configs import WALLET_SEED
from constants import ReturningUser
from constants.wallet import WalletNetworkSettings
from gui.components.authenticate_popup import AuthenticatePopup
from helpers.onboarding_helper import open_create_profile_view, import_seed_and_log_in
from helpers.settings_helper import enable_testnet_mode


def authenticate_with_password(user_account):
    auth_popup = AuthenticatePopup().wait_until_appears()
    auth_popup.authenticate(user_account.password)
    auth_popup.wait_until_hidden()


def open_send_modal_for_account(main_window, account_name):
    wallet = main_window.left_panel.open_wallet()
    assert wallet.left_panel.all_accounts_balance.wait_until_appears().is_visible, \
        f"Total balance is not visible"
    wallet_account = wallet.left_panel.select_account(account_name)
    send_popup = wallet_account.open_send_popup()
    return send_popup


def wallet_send_returning_user():
    return ReturningUser(
        seed_phrase=WALLET_SEED,
        status_address='0x44ddd47a0c7681a5b0fa080a56cbb7701db4bb43')


def wallet_send_import_and_open_send_modal(main_window, user_account):
    with step('Import seed and log in'):
        with step('Open Create your profile view'):
            create_your_profile_view = open_create_profile_view()
        with step('Import seed and log in'):
            import_seed_and_log_in(create_your_profile_view, user_account.seed_phrase, user_account)

    with step('Set testnet mode'):
        enable_testnet_mode(main_window)

    with step('Open wallet send popup'):
        return open_send_modal_for_account(
            main_window, account_name=WalletNetworkSettings.STATUS_ACCOUNT_DEFAULT_NAME.value)


def assert_wallet_send_toast(main_window, receiver_account_address):
    toast_messages = ' '.join(main_window.wait_for_toast_notifications()).replace('×', 'x')
    account_name = WalletNetworkSettings.STATUS_ACCOUNT_DEFAULT_NAME.value
    address_start = receiver_account_address[:6]
    normalized_toast = ' '.join(toast_messages.split())

    has_sending_or_sent = ('Sending' in normalized_toast or 'Sent' in normalized_toast)
    has_account_name = account_name in normalized_toast
    has_address = address_start in normalized_toast

    assert (has_sending_or_sent and has_account_name and has_address), (
        f'Expected toast message with "Sending" or "Sent", account "{account_name}", '
        f'and address starting with "{address_start}", but got: {toast_messages}')
