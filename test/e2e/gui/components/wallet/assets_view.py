import time
import typing

import allure

import configs
import driver
from constants import TokenListItem
from constants.wallet import WALLET_ACCOUNT_EXPECTED_ASSET_TITLES
from gui.components.wallet.asset_details_view import AssetDetailsView
from gui.elements.object import QObject
from gui.objects_map import wallet_names


class AssetsView(QObject):

    def __init__(self):
        super().__init__(wallet_names.assets_view)

        self.asset = QObject(wallet_names.assets_viewTokenItem)

    @property
    @allure.step('Get list of assets')
    def assets(self) -> typing.List[TokenListItem]:
        real_name = dict(self.asset.real_name)
        real_name.pop('index', None)

        started_at = time.monotonic()
        raw_items: typing.List = []
        while not raw_items and (time.monotonic() - started_at) < configs.timeouts.UI_LOAD_TIMEOUT_MSEC:
            raw_items = driver.findAllObjects(real_name)
            if not raw_items:
                time.sleep(0.2)

        assert raw_items, 'No assets found in wallet assets view'

        items = [
            TokenListItem(str(getattr(item, 'title', '')), QObject(real_name=driver.objectMap.realName(item)))
            for item in raw_items
        ]
        return sorted(items, key=lambda token: token.object.y)

    @allure.step('Wait until expected assets are visible in the list')
    def wait_until_expected_assets(
        self,
        expected_titles: typing.AbstractSet[str] = WALLET_ACCOUNT_EXPECTED_ASSET_TITLES,
        timeout_msec: int = configs.timeouts.WALLET_SYNC_TIMEOUT_MSEC,
    ) -> 'AssetsView':
        def all_expected_present():
            titles = {asset.title for asset in self.assets}
            return expected_titles.issubset(titles)

        assert driver.waitFor(all_expected_present, timeout_msec), (
            f'Not all expected assets are visible yet, expected {expected_titles}'
        )
        return self

    @allure.step('Open asset')
    def open_asset_details(self, asset_name):
        self.asset.real_name['objectName'] = 'AssetView_TokenListItem_'+ asset_name
        self.asset.click()
        return AssetDetailsView().wait_until_appears().wait_until_header_loaded()
