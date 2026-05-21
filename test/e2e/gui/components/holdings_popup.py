import time
import typing

import allure

import configs
import driver
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.text_edit import TextEdit
from gui.objects_map import communities_names


class HoldingsPopup(QObject):
    def __init__(self):
        super().__init__(communities_names.holdingsPopup)
        self._search_edit = TextEdit(communities_names.holdingsPopup_assetSearch_TextEdit)
        self._token_item = QObject(communities_names.holdingsPopup_TokenItem)
        self._assets_tab = Button(communities_names.holdingsPopup_AssetsTab_StatusSwitchTabButton)
        self._collectibles_tab = Button(communities_names.holdingsPopup_CollectiblesTab_StatusSwitchTabButton)
        self._mint_asset_button = Button(communities_names.holdingsPopup_MintAsset_StatusIconTextButton)

    @allure.step('Wait until Holdings dropdown appears')
    def wait_until_appears(
            self,
            timeout_msec: int = configs.timeouts.FEES_TIMEOUT_MSEC,
            check_interval=0.5,
    ):
        # Slower CI (e.g. Jenkins Ubuntu) often needs >5s for dropdown + token list after plus click.
        super().wait_until_appears(timeout_msec, check_interval)
        self._search_edit.wait_until_appears(timeout_msec)
        return self

    @allure.step('Switch Holdings popup to Assets tab')
    def open_assets_tab(self):
        self._assets_tab.wait_until_appears().click()
        return self

    @allure.step('Switch Holdings popup to Collectibles tab')
    def open_collectibles_tab(self):
        self._collectibles_tab.wait_until_appears().click()
        return self

    @allure.step('Click Mint asset in holdings list header')
    def click_mint_asset(self):
        self._mint_asset_button.wait_until_appears().click()
        return self

    @allure.step('Set holdings search text')
    def set_search_text(self, text: str):
        self._search_edit.wait_until_appears()
        self._search_edit.set_text_property(text)
        return self

    @allure.step('Wait until list search field is hidden (token selected, amount panel)')
    def wait_until_list_search_hidden(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self._search_edit.wait_until_hidden(timeout_msec)
        return self

    @allure.step('Select asset or collectible row matching name')
    def select_asset_from_list(self, asset: str, index: typing.Optional[int] = None):
        token_real_name = dict(self._token_item.real_name)
        token_real_name.pop('index', None)

        started_at = time.monotonic()
        asset_items: typing.List = []
        while not asset_items and (time.monotonic() - started_at) < configs.timeouts.UI_LOAD_TIMEOUT_SEC:
            asset_items = driver.findAllObjects(token_real_name)
            if not asset_items:
                time.sleep(0.2)
        assert asset_items, 'No TokenItem rows in holdings list'

        matching_indices: typing.List[int] = []
        for i, item in enumerate(asset_items):
            item_title = getattr(item, 'title', '')
            item_name = getattr(item, 'name', '')
            item_symbol = getattr(item, 'symbol', '')
            if (asset.lower() in str(item_title).lower()
                    or asset.lower() in str(item_name).lower()
                    or asset.lower() in str(item_symbol).lower()):
                matching_indices.append(i)

        if not matching_indices:
            sample_attrs = []
            if asset_items:
                sample_item = asset_items[0]
                for attr in ('title', 'name', 'symbol'):
                    val = getattr(sample_item, attr, None)
                    if val:
                        sample_attrs.append(f'{attr}="{val}"')
            raise AssertionError(
                f'No assets found matching "{asset}". '
                f'Found {len(asset_items)} items. '
                f'Sample attributes: {", ".join(sample_attrs) if sample_attrs else "none"}'
            )

        if len(matching_indices) > 1 and index is not None:
            assert 0 <= index < len(matching_indices), (
                f'Index {index} is out of range. Found {len(matching_indices)} matching items'
            )
            selected_in_matching = index
        else:
            selected_in_matching = 0

        item_index_in_full_list = matching_indices[selected_in_matching]
        row = QObject(dict(self._token_item.real_name))
        row.real_name['index'] = item_index_in_full_list
        row.click()
        return self

    @allure.step('Search and select asset in holdings dropdown')
    def search_and_select_asset(self, asset: str, index: typing.Optional[int] = None):
        self.set_search_text(asset)
        time.sleep(0.5)
        self.select_asset_from_list(asset, index=index)
        return self
