from allure_commons._allure import step

import configs
import driver
from configs import WALLET_SEED
from driver.objects_access import item_is_visible
from gui.objects_map import wallet_names
from constants import ReturningUser
from constants.wallet import WalletNetworkSettings
from gui.components.authenticate_popup import AuthenticatePopup
from helpers.onboarding_helper import open_create_profile_view, import_seed_and_log_in
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


def _asset_items_finished_loading(asset_item) -> bool:
    items = driver.findAllObjects(asset_item.real_name)
    if not items:
        return False
    try:
        return not any(getattr(item, 'balanceLoading', False) for item in items)
    except (RuntimeError, AttributeError):
        # Squish may briefly return destroyed/null asset delegates while the list rebuilds.
        return False


def _activity_store_from_transaction_list(transaction_list):
    current = transaction_list
    for _ in range(32):
        if current is None:
            return None
        activity_store = getattr(current, 'activityStore', None)
        if activity_store is not None:
            return activity_store
        current = getattr(current, 'parent', None)
    return None


def _find_wallet_activity_store(transaction_list=None):
    if transaction_list is not None:
        activity_store = _activity_store_from_transaction_list(transaction_list)
        if activity_store is not None:
            return activity_store

    for history_view in driver.findAllObjects({
        'container': wallet_names.mainWindow_RightTabView,
        'type': 'HistoryView',
    }):
        activity_store = getattr(history_view, 'activityStore', None)
        if activity_store is not None:
            return activity_store
    return None


def _activity_empty_state_visible() -> bool:
    for item in driver.findAllObjects(wallet_names.activity_empty_state):
        if item_is_visible(item):
            return True
    return False


def _activity_loading_placeholders_visible() -> bool:
    for item in driver.findAllObjects({
        'container': wallet_names.mainWindow_RightTabView,
        'type': 'TransactionDelegate',
    }):
        try:
            if getattr(item, 'loading', False) and item_is_visible(item):
                return True
        except (RuntimeError, AttributeError):
            continue
    return False


def _activity_initial_loading_indicator_visible() -> bool:
    for item in driver.findAllObjects({
        'container': wallet_names.mainWindow_RightTabView,
        'type': 'StatusTextWithLoadingState',
    }):
        try:
            if getattr(item, 'loading', False) and item_is_visible(item):
                return True
        except (RuntimeError, AttributeError):
            continue
    return False


def _read_activity_history_loading(activity_store):
    loading = getattr(activity_store, 'loadingHistoryTransactions', None)
    if loading is not None:
        return bool(loading)

    wallet_section = getattr(activity_store, 'walletSectionInst', None)
    if wallet_section is not None:
        controller = getattr(wallet_section, 'activityController', None)
        if controller is not None:
            status = getattr(controller, 'status', None)
            if status is not None:
                loading_data = getattr(status, 'loadingData', None)
                if loading_data is not None:
                    return bool(loading_data)
    return None


def is_activity_tab_content_loaded(activity_view) -> bool:
    if not activity_view.exists:
        return False

    try:
        transaction_list = activity_view.object
    except (LookupError, RuntimeError, AttributeError):
        return False

    if getattr(transaction_list, 'count', 0) > 0:
        return True

    if _activity_loading_placeholders_visible() or _activity_initial_loading_indicator_visible():
        return False

    if _activity_empty_state_visible():
        return True

    activity_store = _find_wallet_activity_store(transaction_list)
    if activity_store is not None:
        loading = _read_activity_history_loading(activity_store)
        if loading is not None:
            return not loading

    return True


@step('Wait for account assets to finish loading')
def wait_for_account_assets_loaded(
        wallet_account_view,
        timeout_msec: int = configs.timeouts.WALLET_SYNC_TIMEOUT_MSEC,
        open_tab: bool = True,
):
    if open_tab:
        wallet_account_view.open_assets_tab(wait_until_loaded=True, loading_timeout_msec=timeout_msec)
    else:
        wallet_account_view.wait_for_assets_tab_content_loaded(timeout_msec)


def authenticate_with_password(user_account):
    auth_popup = AuthenticatePopup().wait_until_appears()
    auth_popup.authenticate(user_account.password)
    auth_popup.wait_until_hidden()


@step('Open wallet and send modal after balances are loaded')
def open_send_modal_for_account(main_window, account_name):
    timeout_msec = configs.timeouts.WALLET_TRANSACTION_SYNC_TIMEOUT_MSEC
    wallet = main_window.left_panel.open_wallet()
    wait_for_wallet_balances_loaded(wallet.left_panel, timeout_msec=timeout_msec)
    wallet_account = wallet.left_panel.select_account(account_name)
    wait_for_account_assets_loaded(wallet_account, timeout_msec=timeout_msec)
    return wallet_account.open_send_popup()


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

    with step('Open wallet send popup after balances are loaded'):
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
