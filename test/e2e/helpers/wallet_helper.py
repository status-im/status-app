from allure_commons._allure import step

import configs
import driver
from configs import WALLET_SEED
from gui.objects_map import wallet_names
from constants import ReturningUser
from constants.wallet import WalletNetworkSettings
from gui.components.authenticate_popup import AuthenticatePopup
from helpers.onboarding_helper import (
    import_seed_and_log_in,
    open_create_profile_view,
    skip_post_login_popups_if_visible,
)
from helpers.settings_helper import enable_testnet_mode


@step('Wait for wallet balances to finish loading')
def wait_for_wallet_balances_loaded(
        wallet_left_panel,
        timeout_msec: int = configs.timeouts.WALLET_SYNC_TIMEOUT_MSEC,
):
    balance = wallet_left_panel.all_accounts_balance
    balance.wait_until_appears(timeout_msec)

    assert driver.waitFor(
        lambda: not getattr(balance.object, 'loading', False) and bool(balance.text.strip()),
        timeout_msec,
    ), f'Wallet total balance is still loading, got: {balance.text!r}'


def is_assets_tab_content_loaded(asset_item) -> bool:
    views = driver.findAllObjects(wallet_names.assets_view)
    try:
        if not (views and getattr(views[0], 'visible', False)):
            return False
    except (RuntimeError, AttributeError):
        return False

    items = driver.findAllObjects(asset_item.real_name)
    return bool(items) and all(not getattr(item, 'balanceLoading', False) for item in items)


def is_activity_tab_content_loaded() -> bool:
    views = driver.findAllObjects(wallet_names.activity_history_view)
    try:
        return bool(views) and bool(getattr(views[0], 'contentLoaded', False))
    except (RuntimeError, AttributeError):
        return False


@step('Wait for account assets to finish loading')
def wait_for_account_assets_loaded(
        wallet_account_view,
        timeout_msec: int = configs.timeouts.WALLET_SYNC_TIMEOUT_MSEC,
):
    wallet_account_view.open_assets_tab(wait_until_loaded=True, loading_timeout_msec=timeout_msec)


def authenticate_with_password(user_account):
    auth_popup = AuthenticatePopup().wait_until_appears()
    auth_popup.authenticate(user_account.password)
    auth_popup.wait_until_hidden()


@step('Verify authentication popup does not appear')
def assert_authenticate_popup_not_appears(timeout_msec: int = 2000):
    AuthenticatePopup().assert_does_not_appear(timeout_msec)


@step('Open wallet account after balances are loaded')
def open_wallet_account(main_window, account_name=None):
    account_name = account_name or WalletNetworkSettings.STATUS_ACCOUNT_DEFAULT_NAME.value
    wallet = main_window.left_panel.open_wallet()
    wait_for_wallet_balances_loaded(wallet.left_panel)
    return wallet.left_panel.select_account(account_name)


def wallet_send_returning_user():
    return ReturningUser(
        seed_phrase=WALLET_SEED,
        status_address='0x44ddd47a0c7681a5b0fa080a56cbb7701db4bb43')


def wallet_send_import_user(main_window, user_account):
    with step('Import seed and log in'):
        import_seed_and_log_in(
            open_create_profile_view(),
            user_account.seed_phrase,
            user_account,
        )
        skip_post_login_popups_if_visible()

    with step('Enable testnet mode'):
        enable_testnet_mode(main_window)
        skip_post_login_popups_if_visible()
