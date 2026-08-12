import time
import typing

import allure

import configs
import driver
from constants.community import MintOwnerTokensElements
from gui.components.sign_transaction_popup import SignTransactionPopup
from gui.elements.button import Button
from gui.elements.check_box import CheckBox
from gui.elements.object import QObject
from gui.elements.scroll import Scroll
from gui.elements.text_label import TextLabel
from gui.objects_map import communities_names


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
        self.mint_owner_token_button.click()
        return TokensOwnerTokenSettingsView().wait_until_appears()


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
        self._mainnet_network_item = CheckBox(communities_names.mainnet_StatusRadioButton)
        self.optimism_network_item = CheckBox(communities_names.optimism_StatusRadioButton)
        self.arbitrum_network_item = CheckBox(communities_names.arbitrum_StatusRadioButton)
        self.network_item = CheckBox(communities_names.networkItem_StatusRadioButton)
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

    def select_network(self, network_name):
        if not self._fees_box.is_visible:
            self._scroll.vertical_scroll_down(self._fees_box)
        self._select_network_filter.click()
        network_options = driver.findAllObjects(self.network_item.real_name)
        assert network_options, f'Network options are not displayed'
        for item in network_options:
            if str(getattr(item, 'objectName', '')).endswith(network_name):
                QObject(item).click()
                time.sleep(0.5)  # allow network selector component to hide
                break
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
