import time

import allure

from constants.community import MintOwnerTokensElements
from gui.screens.community_settings_tokens import (
    MintedTokensView,
    TokensView,
)
from gui.screens.settings_wallet import WalletSettingsView
from helpers.settings_helper import open_wallet_settings
from helpers.wallet_helper import assert_authenticate_popup_not_appears


@allure.step('Mint Owner and TokenMaster tokens on {network_name}')
def mint_owner_and_tokenmaster(community_setting, password: str, network_name: str, community_name: str):
    tokens_screen = community_setting.left_panel.open_tokens().click_mint_owner_button()
    edit_owner_token_view = tokens_screen.click_next()
    edit_owner_token_view.select_network(network_name)
    expected_fee_title = (
        'Mint ' + community_name
        + MintOwnerTokensElements.SIGN_TRANSACTION_MINT_TITLE.value
        + network_name
    )
    assert edit_owner_token_view.get_fee_title == expected_fee_title, (
        f'{edit_owner_token_view.get_fee_title!r} != {expected_fee_title!r}'
    )
    edit_owner_token_view.wait_until_mint_fees_loaded(network_name)
    start_minting = edit_owner_token_view.mint()
    start_minting.sign_transaction(password)
    sent_at = time.time()
    MintedTokensView().check_community_collectibles_statuses(community_name)
    return sent_at


@allure.step('Mint community token {name}')
def mint_community_token(
        tokens_view: TokensView,
        password: str,
        name: str,
        description: str,
        symbol: str,
        supply: str,
        network_name: str,
        is_asset: bool = False,
):
    edit_view = tokens_view.click_mint_token()
    edit_view.fill_form(name, description, symbol, supply, is_asset=is_asset)
    fee_title = f'Mint {"asset" if is_asset else "collectible"} on {network_name}'
    edit_view.show_fees_and_preview(expected_fee_title=fee_title)
    edit_view.mint_and_sign(password)
    sent_at = time.time()
    minted = MintedTokensView().wait_until_appears()
    if is_asset:
        minted.wait_until_asset_minted(name)
    else:
        minted.wait_until_collectible_minted(name)
    return sent_at


@allure.step('Add generated wallet account and return its address')
def add_generated_account_address(main_window, account_name: str) -> str:
    add_account_popup = open_wallet_settings(main_window).open_add_account_pop_up()
    add_account_popup.set_name(account_name).save_changes()
    assert_authenticate_popup_not_appears()
    add_account_popup.wait_until_hidden()
    acc_view = WalletSettingsView().open_account_in_settings(account_name, 1)
    address = acc_view.get_account_address_value()
    assert address, f'Generated account {account_name!r} has no address'
    return address
