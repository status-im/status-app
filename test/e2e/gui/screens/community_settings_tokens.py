import pathlib
import typing

import allure

import configs
import driver
from constants.community import MintOwnerTokensElements
from driver.objects_access import walk_children
from gui.components.picture_edit_popup import PictureEditPopup
from gui.components.sign_transaction_popup import SignTransactionPopup
from gui.components.wallet.send_popup import SendPopup
from gui.elements.button import Button
from gui.elements.check_box import CheckBox
from gui.elements.object import QObject
from gui.elements.scroll import Scroll
from gui.elements.text_edit import TextEdit
from gui.elements.text_label import TextLabel
from gui.objects_map import communities_names
from helpers.wallet_helper import select_network_in_filter


class TokensView(QObject):
    def __init__(self):
        super(TokensView, self).__init__(communities_names.mainWindow_mintPanel_MintTokensSettingsPanel)
        self.mint_token_button = Button(communities_names.mainWindow_Mint_token_StatusButton)
        self.welcome_image = QObject(communities_names.welcomeSettingsTokens_Image)
        self.welcome_title = TextLabel(communities_names.welcomeSettingsTokens_Title)
        self.welcome_subtitle = TextLabel(communities_names.welcomeSettingsTokensSubtitle)
        self.welcome_checklist_1 = TextLabel(communities_names.checkListText_0_Tokens)
        self.welcome_checklist_2 = TextLabel(communities_names.checkListText_1_Tokens)
        self.welcome_checklist_3 = TextLabel(communities_names.checkListText_2_Tokens)
        self.get_started_infobox = QObject(communities_names.mint_Owner_Tokens_InfoBoxPanel)
        self.mint_owner_token_button = Button(communities_names.mint_Owner_Tokens_StatusButton)
        self._scroll = Scroll(communities_names.mainWindow_MintedTokensView)

    @property
    @allure.step('Get mint token button enable state')
    def is_mint_token_button_enabled(self) -> bool:
        return driver.waitForObjectExists(self.mint_token_button.real_name,
                                          configs.timeouts.UI_LOAD_TIMEOUT_MSEC).enabled

    @property
    @allure.step('Get tokens welcome image path')
    def tokens_welcome_image_path(self) -> str:
        return self.welcome_image.object.source.path

    @property
    @allure.step('Get tokens welcome title')
    def tokens_welcome_title(self) -> str:
        return self.welcome_title.text

    @property
    @allure.step('Get tokens welcome subtitle')
    def tokens_welcome_subtitle(self) -> str:
        return self.welcome_subtitle.text

    @property
    @allure.step('Get tokens checklist')
    def tokens_checklist(self) -> typing.List[str]:
        tokens_checklist = [str(self.welcome_checklist_1.object.text), str(self.welcome_checklist_2.object.text),
                            str(self.welcome_checklist_3.object.text)]
        return tokens_checklist

    @property
    @allure.step('Get tokens info box title')
    def tokens_infobox_title(self) -> str:
        return str(self.get_started_infobox.object.title)

    @property
    @allure.step('Get tokens info box text')
    def tokens_infobox_text(self) -> str:
        return str(self.get_started_infobox.object.text)

    @allure.step('Click mint owner button')
    def click_mint_owner_button(self):
        self._scroll.vertical_scroll_down(self.mint_owner_token_button)
        self.mint_owner_token_button.click()
        return TokensOwnerTokenSettingsView().wait_until_appears()

    @allure.step('Click mint token')
    def click_mint_token(self) -> 'EditCommunityTokenView':
        assert driver.waitFor(
            lambda: self.is_mint_token_button_enabled,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), 'Mint token button is not enabled'
        self.mint_token_button.click()
        return EditCommunityTokenView().wait_until_appears()


class TokensOwnerTokenSettingsView(QObject):
    def __init__(self):
        super(TokensOwnerTokenSettingsView, self).__init__(communities_names.mintTokenSettingsPanel)
        self._scroll = Scroll(communities_names.mainWindow_OwnerTokenWelcomeView)
        self._owner_token_section = QObject(communities_names.ownerToken_InfoPanel)
        self._token_master_token_section = QObject(communities_names.tokenMasterToken_InfoPanel)
        self._next_button = Button(communities_names.mintOwnerTokenViewNextButton)
        self._owner_token_text_object = TextLabel(communities_names.owner_token_StatusBaseText)
        self._token_master_text_object = TextLabel(communities_names.token_master_StatusBaseText)

    @property
    @allure.step('Get all text from owner token panel')
    def get_text_labels_from_owner_token_panel(self) -> list:
        if not self._owner_token_section.is_visible:
            self._scroll.vertical_scroll_down(self._owner_token_section)
        owner_token_text_labels = []
        for item in driver.findAllObjects(self._owner_token_text_object.real_name):
            owner_token_text_labels.append(item)
        return sorted(owner_token_text_labels, key=lambda item: item.y)

    @allure.step('Verify text on owner token panel')
    def verify_text_on_owner_token_panel(self):
        assert str(self.get_text_labels_from_owner_token_panel[2].text) \
               == MintOwnerTokensElements.OWNER_TOKEN_CHEKLIST_ELEMENT_1.value, f'Actual text is {self.get_text_labels_from_owner_token_panel[2].text}'
        assert str(self.get_text_labels_from_owner_token_panel[3].text) \
               == MintOwnerTokensElements.OWNER_TOKEN_CHEKLIST_ELEMENT_2.value, f'Actual text is {self.get_text_labels_from_owner_token_panel[3].text}'
        assert str(self.get_text_labels_from_owner_token_panel[4].text) \
               == MintOwnerTokensElements.OWNER_TOKEN_CHEKLIST_ELEMENT_3.value, f'Actual text is {self.get_text_labels_from_owner_token_panel[4].text}'
        assert str(self.get_text_labels_from_owner_token_panel[5].text) \
               == MintOwnerTokensElements.OWNER_TOKEN_CHEKLIST_ELEMENT_4.value, f'Actual text is {self.get_text_labels_from_owner_token_panel[5].text}'

    @allure.step('Verify text on master token panel')
    def verify_text_on_master_token_panel(self):
        assert str(self.get_text_labels_from_master_token_panel[
                       3].text) == MintOwnerTokensElements.MASTER_TOKEN_CHEKLIST_ELEMENT_1.value, f'Actual text is {self.get_text_labels_from_master_token_panel[3].text}'
        assert str(self.get_text_labels_from_master_token_panel[
                       4].text) == MintOwnerTokensElements.MASTER_TOKEN_CHEKLIST_ELEMENT_2.value, f'Actual text is {self.get_text_labels_from_master_token_panel[4].text}'
        assert str(self.get_text_labels_from_master_token_panel[
                       5].text) == MintOwnerTokensElements.MASTER_TOKEN_CHEKLIST_ELEMENT_3.value, f'Actual text is {self.get_text_labels_from_master_token_panel[5].text}'
        assert str(self.get_text_labels_from_master_token_panel[
                       6].text) == MintOwnerTokensElements.MASTER_TOKEN_CHEKLIST_ELEMENT_4.value, f'Actual text is {self.get_text_labels_from_master_token_panel[6].text}'
        assert str(self.get_text_labels_from_master_token_panel[
                       7].text) == MintOwnerTokensElements.MASTER_TOKEN_CHEKLIST_ELEMENT_5.value, f'Actual text is {self.get_text_labels_from_master_token_panel[5].text}'

    @property
    @allure.step('Get all text from master token panel')
    def get_text_labels_from_master_token_panel(self) -> list:
        if not self._token_master_token_section.is_visible:
            self._scroll.vertical_scroll_down(self._token_master_token_section)
        master_token_text_labels = []
        for item in driver.findAllObjects(self._token_master_text_object.real_name):
            master_token_text_labels.append(item)
        return sorted(master_token_text_labels, key=lambda item: item.y)

    @allure.step('Click next button and open Edit owner token view')
    def click_next(self):
        for _ in range(2):
            try:
                self._scroll.vertical_scroll_down(self._next_button)
                self._next_button.click()
                return EditOwnerTokenView().wait_until_appears()
            except Exception:
                pass
        raise RuntimeError("Can't open Edit owner token view")


class EditOwnerTokenView(QObject):
    def __init__(self):
        super(EditOwnerTokenView, self).__init__(communities_names.mainWindow_editOwnerTokenView_EditOwnerTokenView)
        self._scroll = Scroll(communities_names.mainWindow_editOwnerTokenView_EditOwnerTokenView)
        self._select_account_combobox = QObject(communities_names.editOwnerTokenView_CustomComboItem)
        self._select_network_filter = QObject(communities_names.editOwnerTokenView_netFilter_NetworkFilter)
        self._select_network_combobox = QObject(communities_names.editOwnerTokenView_comboBox_ComboBox)
        self._selected_network_text = TextLabel(communities_names.editOwnerTokenView_selectedNetworkText)
        self._mainnet_network_item = CheckBox(communities_names.mainnet_StatusRadioButton)
        self.optimism_network_item = CheckBox(communities_names.optimism_StatusRadioButton)
        self.arbitrum_network_item = CheckBox(communities_names.arbitrum_StatusRadioButton)
        self.network_item = CheckBox(communities_names.networkItem_StatusRadioButton)
        self.network_delegate = QObject(communities_names.networkSelectorDelegate)
        self._mint_button = Button(communities_names.editOwnerTokenView_Mint_StatusButton)
        self._fees_text_object = TextLabel(communities_names.editOwnerTokenView_fees_StatusBaseText)
        self._crown_icon = QObject(communities_names.editOwnerTokenView_crown_icon_StatusIcon)
        self._coin_icon = QObject(communities_names.editOwnerTokenView_token_sale_icon_StatusIcon)
        self._symbol_box = QObject(communities_names.editOwnerTokenView_symbolBox)
        self._total_box = QObject(communities_names.editOwnerTokenView_totalBox)
        self._remaining_box = QObject(communities_names.editOwnerTokenView_remainingBox)
        self._transferable_box = QObject(communities_names.editOwnerTokenView_transferableBox)
        self._destructible_box = QObject(communities_names.editOwnerTokenView_destructibleBox)
        self._edit_owner_token_text_object = TextLabel(communities_names.editOwnerTokenView_Owner_StatusBaseText)
        self._fees_box = QObject(communities_names.editOwnerTokenView_Fees_FeesBox)

    @property
    @allure.step('Get selected network name')
    def selected_network_name(self) -> str:
        if not self._selected_network_text.exists:
            return ''
        return self._selected_network_text.text

    @property
    @allure.step('Get fee title')
    def get_fee_title(self) -> str:
        return str(self.object.feeLabel)

    @property
    @allure.step('Get fee total value')
    def get_fee_total_value(self) -> str:
        return str(self.object.feeText)

    @property
    @allure.step('Get crown symbol')
    def get_crown_symbol(self) -> bool:
        return self._crown_icon.exists

    @allure.step('Get text labels')
    def get_all_text_labels(self) -> list:
        text_labels = []
        for item in driver.findAllObjects(self._edit_owner_token_text_object.real_name):
            text_labels.append(str(item.text))
        return text_labels

    @allure.step('Get all symbol boxes')
    def get_symbol_boxes(self):
        symbol_boxes = []
        for item in driver.findAllObjects(self._symbol_box.real_name):
            symbol_boxes.append(item)
        sorted(symbol_boxes, key=lambda item: item.y)
        return symbol_boxes

    @allure.step('Get all total boxes')
    def get_total_boxes(self):
        total_boxes = []
        for item in driver.findAllObjects(self._total_box.real_name):
            total_boxes.append(item)
        sorted(total_boxes, key=lambda item: item.y)
        return total_boxes

    @allure.step('Get all remaining boxes')
    def get_remaining_boxes(self):
        remaining_boxes = []
        for item in driver.findAllObjects(self._remaining_box.real_name):
            remaining_boxes.append(item)
        sorted(remaining_boxes, key=lambda item: item.y)
        return remaining_boxes

    @allure.step('Get all destructible boxes')
    def get_destructible_boxes(self):
        destructible_boxes = []
        for item in driver.findAllObjects(self._destructible_box.real_name):
            destructible_boxes.append(item)
        sorted(destructible_boxes, key=lambda item: item.y)
        return destructible_boxes

    @allure.step('Get all transferable boxes')
    def get_transferable_boxes(self):
        transferable_boxes = []
        for item in driver.findAllObjects(self._transferable_box.real_name):
            transferable_boxes.append(item)
        sorted(transferable_boxes, key=lambda item: item.y)
        return transferable_boxes

    @allure.step('Get owner symbol box content')
    def get_symbol_box_content(self, index: int) -> str:
        symbol_box = self.get_symbol_boxes()[index]
        return str(symbol_box.value)

    @allure.step('Get total box content')
    def get_total_box_content(self, index: int) -> str:
        total_box = self.get_total_boxes()[index]
        return str(total_box.value)

    @allure.step('Get remaining box content')
    def get_remaining_box_content(self, index: int) -> str:
        remaining_box = self.get_remaining_boxes()[index]
        return str(remaining_box.value)

    @allure.step('Get transferable box content')
    def get_transferable_box_content(self, index: int) -> str:
        transferable_box = self.get_transferable_boxes()[index]
        return str(transferable_box.value)

    @allure.step('Get destructible box content')
    def get_destructible_box_content(self, index: int) -> str:
        destructible_box = self.get_destructible_boxes()[index]
        return str(destructible_box.value)

    @allure.step('Select network {1}')
    def select_network(self, network_name: str):
        self._scroll.vertical_scroll_down(self._select_network_filter)
        select_network_in_filter(
            self._select_network_filter,
            network_name,
            self.network_delegate.real_name,
            self.network_item.real_name,
            selected_label=self._selected_network_text,
        )
        assert driver.waitFor(
            lambda: network_name in self.get_fee_title,
            configs.timeouts.FEES_TIMEOUT_MSEC,
        ), f'feeLabel {self.get_fee_title!r} does not include {network_name!r}'
        return self

    @allure.step('Wait until mint fees are loaded for {1}')
    def wait_until_mint_fees_loaded(self, network_name: str):
        assert driver.waitFor(
            lambda: self.get_fee_total_value != '',
            configs.timeouts.FEES_TIMEOUT_MSEC,
        ), (
            f'Fees did not load for {network_name!r}: '
            f'feeLabel={self.get_fee_title!r}, feeText={self.get_fee_total_value!r}'
        )
        return self

    @allure.step('Click mint button')
    def mint(self):
        for _ in range(3):
            try:
                self._scroll.vertical_scroll_down(self._mint_button)
                self._mint_button.click()
                return SignTransactionPopup().wait_until_appears()
            except Exception:
                pass  # Retry one more time
        raise RuntimeError(f'Could not open Sign transaction popup')


class MintedTokensView(QObject):
    COMPLETED_STATUSES = frozenset({'∞', '1 of 1 (you hodl)'})
    FAILED_STATUS = 'Minting failed'

    def __init__(self):
        super().__init__(communities_names.mainWindow_MintedTokensView)
        self.collectible = QObject(communities_names.collectibleView_control)
        self.back_button = Button(communities_names.communitySettingsToolBarBackButton)

    def _collectibles(self):
        return driver.findAllObjects(self.collectible.real_name)

    def _collectible_titles(self):
        return {str(getattr(item, 'title', '')) for item in self._collectibles()}

    def _collectible_statuses(self):
        return {str(getattr(item, 'subTitle', '')) for item in self._collectibles()}

    @allure.step('Wait until Owner and TokenMaster collectibles appear')
    def wait_for_owner_and_tokenmaster(self, community_name: str,
                                       timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self.wait_until_appears(timeout_msec)
        expected_titles = {
            f'{MintOwnerTokensElements.OWNER_TOKEN_NAME.value}{community_name}',
            f'{MintOwnerTokensElements.MASTER_TOKEN_NAME.value}{community_name}',
        }
        assert driver.waitFor(
            lambda: len(self._collectibles()) == 2 and expected_titles <= self._collectible_titles(),
            timeout_msec,
        ), (
            f'Expected collectibles {expected_titles}, '
            f'got titles={self._collectible_titles()}, statuses={self._collectible_statuses()}'
        )
        return self

    @allure.step('Verify Owner and TokenMaster mint completed')
    def check_community_collectibles_statuses(self, community_name: str,
                                               timeout_msec: int = 180000):
        self.wait_for_owner_and_tokenmaster(community_name)

        def mint_done_or_failed() -> bool:
            statuses = self._collectible_statuses()
            return self.FAILED_STATUS in statuses or (
                len(self._collectibles()) == 2 and statuses == self.COMPLETED_STATUSES
            )

        driver.waitFor(mint_done_or_failed, timeout_msec)
        statuses = self._collectible_statuses()
        titles = self._collectible_titles()
        if self.FAILED_STATUS in statuses:
            raise AssertionError(
                f'Minting failed for community collectibles: titles={titles}, statuses={statuses}'
            )
        assert statuses == self.COMPLETED_STATUSES and len(self._collectibles()) == 2, (
            f'Token statuses were not completed within {timeout_msec} ms: '
            f'titles={titles}, statuses={statuses}'
        )

    def _collectible_by_title(self, title: str):
        for item in self._collectibles():
            if str(getattr(item, 'title', '')) == title:
                return item
        return None

    def _ensure_collectibles_list(self):
        def list_ready() -> bool:
            if self._collectibles():
                return True
            if self.back_button.is_visible:
                self.back_button.click()
            return False

        assert driver.waitFor(list_ready, configs.timeouts.UI_LOAD_TIMEOUT_MSEC), (
            'Minted collectibles list did not appear'
        )

    def _asset_by_title(self, title: str):
        for item in driver.findAllObjects(communities_names.mintedAssetListItem):
            if str(getattr(item, 'title', '')) == title:
                return item
        return None

    @allure.step('Wait until collectible {1} is minted')
    def wait_until_collectible_minted(self, title: str, timeout_msec: int = 180000):
        def minted() -> bool:
            item = self._collectible_by_title(title)
            if item is None:
                return False
            status = str(getattr(item, 'subTitle', ''))
            if self.FAILED_STATUS in status:
                raise AssertionError(f'Minting failed for {title!r}: {status}')
            return status and 'Minting' not in status

        assert driver.waitFor(minted, timeout_msec), (
            f'Collectible {title!r} was not minted in {timeout_msec} ms; '
            f'titles={self._collectible_titles()}, statuses={self._collectible_statuses()}'
        )
        return self

    @allure.step('Wait until asset {1} is minted')
    def wait_until_asset_minted(self, title: str, timeout_msec: int = 180000):
        def minted() -> bool:
            item = self._asset_by_title(title)
            if item is None:
                return False
            for child in walk_children(item):
                text = str(getattr(child, 'text', ''))
                if self.FAILED_STATUS in text:
                    raise AssertionError(f'Minting failed for asset {title!r}: {text}')
                if 'Minting' in text:
                    return False
            return True

        assert driver.waitFor(minted, timeout_msec), (
            f'Asset {title!r} was not minted in {timeout_msec} ms'
        )
        return self

    @allure.step('Open collectible {1}')
    def open_collectible(self, title: str) -> 'TokenDetailsView':
        self._ensure_collectibles_list()
        assert driver.waitFor(
            lambda: self._collectible_by_title(title) is not None,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), f'Collectible {title!r} not found in {self._collectible_titles()}'
        QObject(self._collectible_by_title(title)).click()
        return TokenDetailsView().wait_until_appears()

    @allure.step('Open owner token {1}')
    def open_owner_token(self, community_name: str) -> 'TokenDetailsView':
        title = f'{MintOwnerTokensElements.OWNER_TOKEN_NAME.value}{community_name}'
        return self.open_collectible(title)


def _set_switch(switch: QObject, value: bool):
    if switch.is_checked is not value:
        switch.click()
        assert driver.waitFor(
            lambda: switch.is_checked is value,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), f'Switch {switch.real_name} did not become {value}'


class EditCommunityTokenView(QObject):
    def __init__(self):
        super().__init__(communities_names.editCommunityTokenView)
        self._scroll = Scroll(communities_names.editCommunityTokenView)
        self.collectibles_tab = Button(communities_names.mintTokenCollectiblesTab)
        self.assets_tab = Button(communities_names.mintTokenAssetsTab)
        self._collectible_artwork = QObject(communities_names.editCommunityTokenCollectibleArtwork)
        self._asset_icon = QObject(communities_names.editCommunityTokenAssetIcon)
        self._name_edit = TextEdit(communities_names.editCommunityTokenNameTextEdit)
        self._description_edit = TextEdit(communities_names.editCommunityTokenDescriptionTextEdit)
        self._symbol_edit = TextEdit(communities_names.editCommunityTokenSymbolTextEdit)
        self._supply_edit = TextEdit(communities_names.editCommunityTokenSupplyTextEdit)
        self._unlimited_supply_switch = CheckBox(communities_names.editCommunityTokenUnlimitedSupplySwitch)
        self._remotely_destruct_switch = CheckBox(communities_names.editCommunityTokenRemotelyDestructSwitch)
        self._show_fees_switch = CheckBox(communities_names.editCommunityTokenShowFeesSwitch)
        self.preview_button = Button(communities_names.editCommunityTokenPreviewButton)
        self._preview_scroll = Scroll(communities_names.communityTokenPreviewView)
        self.mint_button = Button(communities_names.communityTokenMintButton)

    @allure.step('Select Assets tab')
    def select_assets_tab(self):
        self.assets_tab.click()
        return self

    @allure.step('Set artwork from {1}')
    def set_artwork(self, path, is_asset: bool = False):
        artwork = self._asset_icon if is_asset else self._collectible_artwork
        fileuri = pathlib.Path(str(path)).as_uri()
        artwork.object.cropImage(fileuri)
        picture_popup = PictureEditPopup().wait_until_appears()
        picture_popup.make_picture()
        picture_popup.make_picture_button.wait_until_hidden()
        return self

    @allure.step('Fill token form')
    def fill_form(self, name: str, description: str, symbol: str, supply: str, is_asset: bool = False):
        if is_asset:
            self.select_assets_tab()
        self.set_artwork(configs.testpath.TEST_IMAGES / 'comm_logo.jpeg', is_asset=is_asset)
        self._scroll.vertical_scroll_down(self._name_edit)
        self._name_edit.set_text_property(name)
        self._scroll.vertical_scroll_down(self._description_edit)
        self._description_edit.set_text_property(description)
        self._scroll.vertical_scroll_down(self._symbol_edit)
        self._symbol_edit.set_text_property(symbol)
        self._scroll.vertical_scroll_down(self._unlimited_supply_switch)
        _set_switch(self._unlimited_supply_switch, False)
        self._supply_edit.wait_until_appears()
        self._supply_edit.set_text_property(supply)
        return self

    @allure.step('Show fees and open preview')
    def show_fees_and_preview(self, expected_fee_title: str | None = None):
        self._scroll.vertical_scroll_down(self._show_fees_switch)
        assert driver.waitFor(
            lambda: self._show_fees_switch.is_enabled,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), 'Show fees switch is not enabled'
        _set_switch(self._show_fees_switch, True)
        if expected_fee_title:
            assert driver.waitFor(
                lambda: expected_fee_title in str(getattr(self.object, 'feeLabel', '')),
                configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
            ), (
                f'feeLabel {str(getattr(self.object, "feeLabel", ""))!r} '
                f'does not include {expected_fee_title!r}'
            )
        self._scroll.vertical_scroll_down(self.preview_button)
        assert driver.waitFor(
            lambda: self.preview_button.is_enabled,
            configs.timeouts.FEES_TIMEOUT_MSEC,
        ), 'Preview button stayed disabled'
        self.preview_button.click()
        return self

    @allure.step('Mint from preview and sign')
    def mint_and_sign(self, password: str):
        self._preview_scroll.vertical_scroll_down(self.mint_button)
        assert driver.waitFor(
            lambda: self.mint_button.is_enabled,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), 'Mint button stayed disabled'
        popup = None
        last_error = None
        for _ in range(3):
            try:
                self.mint_button.click()
                popup = SignTransactionPopup().wait_until_appears()
                break
            except Exception as exc:
                last_error = exc
        if popup is None:
            raise RuntimeError('Could not open Sign transaction popup for mint') from last_error
        popup.sign_transaction(password)
        return popup


class TokenDetailsView(QObject):
    def __init__(self):
        super().__init__(communities_names.mainWindow_mintPanel_MintTokensSettingsPanel)
        self.airdrop_button = Button(communities_names.airdropTokenButton)
        self.remotely_destruct_button = Button(communities_names.remotelyDestructTokenButton)
        self.burn_button = Button(communities_names.burnRemainingTokensButton)
        self.send_owner_token_button = Button(communities_names.sendOwnerTokenButton)

    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        assert driver.waitFor(
            lambda: self.airdrop_button.is_visible or self.send_owner_token_button.is_visible,
            timeout_msec,
        ), 'Token details footer did not appear'
        return self

    def _read_remaining_tokens(self) -> int | None:
        try:
            boxes = driver.findAllObjects(communities_names.tokenDetailsRemainingBox)
        except Exception:
            return None
        for box in boxes:
            try:
                return int(getattr(box, 'remainingTokens'))
            except (TypeError, ValueError):
                continue
        return None

    @allure.step('Wait until remaining supply is {1}')
    def wait_for_remaining_tokens(
        self,
        expected: int,
        timeout_msec: int = configs.timeouts.WALLET_HISTORY_TX_TIMEOUT_MSEC,
    ):
        seen = None

        def _matches() -> bool:
            nonlocal seen
            seen = self._read_remaining_tokens()
            return seen == expected

        assert driver.waitFor(_matches, timeout_msec), (
            f'Remaining supply is {seen}, expected {expected}'
        )
        return self

    @allure.step('Open airdrop from token footer')
    def open_airdrop(self) -> 'EditAirdropView':
        assert driver.waitFor(
            lambda: self.airdrop_button.is_enabled,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), 'Airdrop button is not enabled'
        self.airdrop_button.click()
        return EditAirdropView().wait_until_appears()

    @allure.step('Open remotely destruct popup')
    def open_remotely_destruct(self) -> 'RemotelyDestructPopup':
        button_name = self.remotely_destruct_button.real_name
        assert driver.waitFor(
            lambda: driver.object.exists(button_name) and bool(
                getattr(driver.waitForObjectExists(button_name, 200), 'enabled', False)
            ),
            180_000,
        ), 'Remotely destruct button is not enabled'
        self.remotely_destruct_button.click()
        return RemotelyDestructPopup().wait_until_appears()

    @allure.step('Open burn remaining tokens popup')
    def open_burn(self) -> 'BurnTokensPopup':
        assert driver.waitFor(
            lambda: self.burn_button.is_enabled,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), 'Burn button is not enabled'
        self.burn_button.click()
        return BurnTokensPopup().wait_until_appears()

    @allure.step('Open transfer ownership popup')
    def open_transfer_ownership(self) -> 'TransferOwnershipPopup':
        assert driver.waitFor(
            lambda: self.send_owner_token_button.is_enabled,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), 'Send Owner token button is not enabled'
        self.send_owner_token_button.click()
        return TransferOwnershipPopup().wait_until_appears()


class EditAirdropView(QObject):
    def __init__(self):
        super().__init__(communities_names.airdropToAddButton)
        self.add_recipient_button = Button(communities_names.airdropToAddButton)
        self.eth_addresses_option = Button(communities_names.airdropEthAddressesOption)
        self.addresses_input = TextEdit(communities_names.airdropAddressesTextEdit)
        self.show_fees_switch = CheckBox(communities_names.airdropShowFeesSwitch)
        self.create_airdrop_button = Button(communities_names.createAirdropButton)

    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self.add_recipient_button.wait_until_appears(timeout_msec)
        return self

    @allure.step('Add ETH recipient {1}')
    def add_eth_recipient(self, address: str):
        self.add_recipient_button.wait_until_appears().click()
        self.eth_addresses_option.wait_until_appears().click()
        self.addresses_input.wait_until_appears()
        self.addresses_input.set_text_property(address)
        driver.type(self.addresses_input.object, '<Return>')
        return self

    @allure.step('Show fees, create airdrop and sign')
    def create_and_sign(self, password: str):
        assert driver.waitFor(
            lambda: self.show_fees_switch.is_enabled,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), 'Airdrop show fees switch is not enabled'
        _set_switch(self.show_fees_switch, True)
        assert driver.waitFor(
            lambda: self.create_airdrop_button.is_enabled,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), 'Create airdrop button stayed disabled'
        self.create_airdrop_button.click()
        SignTransactionPopup().wait_until_appears().sign_transaction(password)
        return self


class RemotelyDestructPopup(QObject):
    def __init__(self):
        super().__init__(communities_names.remotelyDestructPopup)
        self.holder_checkbox = CheckBox(communities_names.tokenHolderSelectCheckBox)
        self.show_fees_switch = CheckBox(communities_names.remotelyDestructShowFeesSwitch)
        self.confirm_button = Button(communities_names.remotelyDestructConfirmButton)
        self.alert_accept_button = Button(communities_names.alertPopupAcceptButton)

    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self.holder_checkbox.wait_until_appears(timeout_msec)
        return self

    @allure.step('Select first holder, confirm and sign remotely destruct')
    def destruct_first_holder_and_sign(self, password: str):
        self.holder_checkbox.wait_until_appears(timeout_msec=configs.timeouts.WALLET_HISTORY_TX_TIMEOUT_MSEC)
        _set_switch(self.holder_checkbox, True)
        assert driver.waitFor(
            lambda: self.show_fees_switch.is_enabled,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), 'Remotely destruct show fees is not enabled'
        _set_switch(self.show_fees_switch, True)
        assert driver.waitFor(
            lambda: self.confirm_button.is_enabled,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), 'Remotely destruct confirm stayed disabled'
        self.confirm_button.click()
        self.alert_accept_button.wait_until_appears().click()
        SignTransactionPopup().wait_until_appears().wait_until_sign_enabled().sign_transaction(password)
        return self


class BurnTokensPopup(QObject):
    def __init__(self):
        super().__init__(communities_names.burnTokensPopup)
        self.all_remaining = CheckBox(communities_names.burnAllRemainingRadioButton)
        self.show_fees_switch = CheckBox(communities_names.burnTokensShowFeesSwitch)
        self.confirm_button = Button(communities_names.burnTokensConfirmButton)

    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self.all_remaining.wait_until_appears(timeout_msec)
        return self

    @allure.step('Burn all remaining supply and sign')
    def burn_all_remaining_and_sign(self, password: str):
        self.all_remaining.wait_until_appears().click()
        assert driver.waitFor(
            lambda: self.all_remaining.is_checked,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), 'All remaining burn option was not selected'
        assert driver.waitFor(
            lambda: self.show_fees_switch.is_enabled,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), 'Burn show fees is not enabled'
        _set_switch(self.show_fees_switch, True)
        assert driver.waitFor(
            lambda: self.confirm_button.is_enabled,
            configs.timeouts.ROUTES_TIMEOUT_MSEC,
        ), 'Burn confirm stayed disabled'
        self.confirm_button.click()
        SignTransactionPopup().wait_until_appears().wait_until_sign_enabled().sign_transaction(password)
        return self


class TransferOwnershipPopup(QObject):
    def __init__(self):
        super().__init__(communities_names.sendOwnerTokenConfirmButton)
        self.ack_checkbox = CheckBox(communities_names.transferOwnershipAckCheckBox)
        self.send_button = Button(communities_names.sendOwnerTokenConfirmButton)

    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self.send_button.wait_until_appears(timeout_msec)
        return self

    @allure.step('Acknowledge and open SimpleSend for Owner token')
    def confirm_and_open_send(self) -> SendPopup:
        _set_switch(self.ack_checkbox, True)
        assert driver.waitFor(
            lambda: self.send_button.is_enabled,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), 'Send Owner token button stayed disabled'
        self.send_button.click()
        return SendPopup().wait_until_appears()


class FinaliseOwnershipPopup(QObject):
    def __init__(self):
        super().__init__(communities_names.finaliseOwnershipPopup)
        self.accept_button = Button(communities_names.finaliseOwnershipAcceptButton)
        self.ack_checkbox = CheckBox(communities_names.finaliseOwnershipAckCheckBox)
        self.show_fees_switch = CheckBox(communities_names.finaliseOwnershipShowFeesSwitch)

    def wait_until_appears(self, timeout_msec: int = configs.timeouts.UI_LOAD_TIMEOUT_MSEC):
        self.accept_button.wait_until_appears(timeout_msec)
        return self

    @allure.step('Finalise ownership, show fees and sign set-signer')
    def finalise_and_sign(self, password: str):
        self.accept_button.click()
        self.ack_checkbox.wait_until_appears()
        _set_switch(self.ack_checkbox, True)
        assert driver.waitFor(
            lambda: self.show_fees_switch.is_enabled,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), 'Finalise show fees is not enabled'
        _set_switch(self.show_fees_switch, True)
        assert driver.waitFor(
            lambda: self.accept_button.is_enabled,
            configs.timeouts.UI_LOAD_TIMEOUT_MSEC,
        ), 'Finalise accept stayed disabled'
        self.accept_button.click()
        SignTransactionPopup().wait_until_appears().sign_transaction(password)
        return self
