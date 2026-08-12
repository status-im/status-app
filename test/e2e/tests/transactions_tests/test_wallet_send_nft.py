import allure
import pytest
from allure_commons._allure import step

from configs import WALLET_SEED
from constants import ReturningUser
from constants.wallet import WalletNetworkSettings
from gui.components.wallet.send_popup import SendPopup
from helpers.onboarding_helper import open_create_profile_view, import_seed_and_log_in
from helpers.settings_helper import enable_testnet_mode
from helpers.wallet_helper import authenticate_with_password, open_send_modal_for_account


@pytest.mark.case(704602)
@pytest.mark.transaction
@pytest.mark.parametrize('receiver_account_address, amount, asset', [
    pytest.param('0x44ddd47a0c7681a5b0fa080a56cbb7701db4bb43', 1, '')
])
@pytest.mark.timeout(timeout=120)
@pytest.mark.skip(reason='https://github.com/status-im/status-desktop/issues/18071')
def test_wallet_send_nft(main_window, user_account, receiver_account_address, amount, asset):

    user_account = ReturningUser(
        seed_phrase=WALLET_SEED,
        status_address='0x44ddd47a0c7681a5b0fa080a56cbb7701db4bb43')

    with step('Import seed and log in'):
        with step('Open Create your profile view'):
            create_your_profile_view = open_create_profile_view()
        with step('Import seed and log in'):
            import_seed_and_log_in(create_your_profile_view, user_account.seed_phrase, user_account)

    with step('Set testnet mode'):
        enable_testnet_mode(main_window)

    with step('Open wallet send popup'):
        send_popup = open_send_modal_for_account(
            main_window, account_name=WalletNetworkSettings.STATUS_ACCOUNT_DEFAULT_NAME.value)

    with step('Sign and send transaction to blockchain'):
        send_popup.sign_and_send(receiver_account_address, amount, asset)

    with step('Authenticate with password'):
        authenticate_with_password(user_account)

    with step('Verify send flow completed'):
        SendPopup().wait_until_hidden()
