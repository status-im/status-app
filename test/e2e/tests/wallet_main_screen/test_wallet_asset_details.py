import pytest

import constants
from constants import WalletNetworkSettings
from constants.wallet import WalletTokenSymbols
from gui.main_window import MainWindow
from tests.wallet_main_screen import marks

pytestmark = marks


@pytest.mark.parametrize('asset_symbol', [WalletTokenSymbols.random_asset_details_symbol()])
def test_check_asset_details_from_wallet(main_screen: MainWindow, asset_symbol: str):
    wallet = main_screen.left_panel.open_wallet()
    account_view = wallet.left_panel.select_account(WalletNetworkSettings.STATUS_ACCOUNT_DEFAULT_NAME.value)
    assets_view = account_view.open_assets_view()

    assert constants.WALLET_ACCOUNT_EXPECTED_ASSET_TITLES.issubset(
        {asset.title for asset in assets_view.assets},
    )

    asset_details_view = assets_view.open_asset_details(asset_symbol)

    assert asset_symbol == asset_details_view.token_symbol
    assert 'Assets' == asset_details_view.back_button_title
    asset_details_view.wait_until_graph_has_data()
