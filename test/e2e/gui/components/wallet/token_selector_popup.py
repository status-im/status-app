import random
import time

import allure

import configs
import driver
from constants.wallet import WalletCollectibleTokenType
from gui.elements.button import Button
from gui.elements.object import QObject
from gui.elements.text_edit import TextEdit
from gui.objects_map import names


def _is_erc721(item) -> bool:
    try:
        return int(item.tokenType) == WalletCollectibleTokenType.ERC721
    except (AttributeError, TypeError, ValueError):
        return False


def _erc721_selectable(items):
    return [item for item in items if _is_erc721(item) and not _is_collection(item)]


def _is_collection(item) -> bool:
    return bool(getattr(item, 'goDeeperIconVisible', False))


def _name(item) -> str:
    return str(getattr(item, 'name', ''))


class TokenSelectorPopup(QObject):
    def __init__(self):
        super().__init__(names.tokenSelectorPanel_TokenSelectorNew)
        self.assets_tab = QObject(names.tokenSelectorPanel_AssetsTab)
        self.collectibles_tab = QObject(names.tokenSelectorPanel_CollectiblesTab)
        self.asset_list_item = QObject(names.tokenSelectorAssetDelegate_template)

    def select_asset_from_list(self, asset_name: str):
        self.assets_tab.click()
        found = []

        def asset_found():
            found[:] = [
                item for item in driver.findAllObjects(self.asset_list_item.real_name)
                if getattr(item, 'symbol', '') == asset_name
            ]
            return bool(found)

        assert driver.waitFor(asset_found, configs.timeouts.LOADING_LIST_TIMEOUT_MSEC), (
            f'Asset with symbol "{asset_name}" did not appear'
        )
        QObject(found[0]).click(x=10, y=10)
        self.wait_until_hidden()
        return self

    def open_collectibles_search_view(self):
        self.collectibles_tab.click()
        return SearchableCollectiblesPanelView().wait_until_appears()


class SearchableCollectiblesPanelView(TokenSelectorPopup):
    def __init__(self):
        super().__init__()
        self.search_bar = TextEdit(names.tokenSelectorSearchBar)
        self.collectible_list_item = QObject(names.tokenSelectorCollectibleDelegate_template)
        self.back_button = Button(names.tokenSelectorBackButton)

    def wait_until_appears(self, timeout_msec: int = configs.timeouts.COLLECTIBLES_SYNC_TIMEOUT_MSEC):
        self._wait_collectibles_loaded(timeout_msec)
        self.search_bar.wait_until_appears(configs.timeouts.UI_LOAD_TIMEOUT_MSEC)
        return self

    def _collectibles(self):
        return driver.findAllObjects(self.collectible_list_item.real_name)

    def _wait_collectibles_loaded(
        self,
        timeout_msec: int = configs.timeouts.COLLECTIBLES_SYNC_TIMEOUT_MSEC,
    ):
        assert driver.waitFor(
            lambda: bool(self._collectibles()),
            timeout_msec,
        ), 'Collectibles list did not load in token selector'

    def _click(self, item):
        QObject(item).click()

    def _go_back(self):
        if self.back_button.is_visible:
            self.back_button.click()
            time.sleep(0.2)

    def _items_named(self, collection_name: str):
        needle = collection_name.lower()
        return [item for item in self._collectibles() if _name(item).lower() == needle]

    @allure.step('Select collectible from collection {collection_name}')
    def select_collectible_from_collection(self, collection_name: str):
        self.search_bar.search(collection_name)

        found = []

        def collection_found():
            matches = self._items_named(collection_name)
            collections = [item for item in matches if _is_collection(item)]
            found[:] = collections or matches
            return bool(found)

        assert driver.waitFor(
            collection_found,
            configs.timeouts.LOADING_LIST_TIMEOUT_MSEC,
        ), f'Collectible collection "{collection_name}" did not appear in search'

        self._click(found[0])
        time.sleep(0.3)
        nested = _erc721_selectable(self._collectibles())
        assert nested, f'No tokens found in collection "{collection_name}"'
        self._click(random.choice(nested))
        return self

    def select_random_collectible(self):
        self._wait_collectibles_loaded()

        opened_collections = set()
        while True:
            tokens, collections = [], []
            for item in self._collectibles():
                if _is_collection(item) and _name(item) not in opened_collections:
                    collections.append(item)
                elif _is_erc721(item):
                    tokens.append(item)

            pool = [('token', item) for item in tokens] + [
                ('collection', item) for item in collections
            ]
            if not pool:
                raise LookupError('No ERC-721 collectibles found in token selector')

            kind, item = random.choice(pool)
            self._click(item)
            if kind == 'token':
                return self

            opened_collections.add(_name(item))
            time.sleep(0.3)
            nested = _erc721_selectable(self._collectibles())
            if nested:
                self._click(random.choice(nested))
                return self
            self._go_back()
