import allure
import pytest
from allure_commons._allure import step

from constants import RandomCommunity

from constants.community import AirdropsElements, TokensElements, PermissionsElements
from constants.images_paths import AIRDROPS_WELCOME_IMAGE_PATH, TOKENS_WELCOME_IMAGE_PATH, PERMISSION_WELCOME_IMAGE_PATH
from gui.main_window import MainWindow


@pytest.mark.case(703198, 703199, 703200)
def test_manage_community_screens_overview(main_screen: MainWindow):
    with step('Create community and select it'):
        community = RandomCommunity()
        main_screen.left_panel.create_community(community_data=community)
        community_screen = main_screen.left_panel.open_community(community.name)

    with step('Open airdrops view from community settings'):
        community_setting = community_screen.left_panel.open_community_settings()
        airdrops_screen = community_setting.left_panel.open_airdrops()

    with step('Verify all elements on airdrops screen'):
        with step('Verify New Airdrop button is disabled'):
            assert airdrops_screen.new_airdrop_button.exists, \
                f'New airdrop button should be disabled by default'
        with step('Airdrops welcome image source path is correct'):
            assert AIRDROPS_WELCOME_IMAGE_PATH in str(airdrops_screen.airdrops_welcome_image_path)
        with step('Airdrops welcome title is correct'):
            assert airdrops_screen.airdrops_welcome_title == AirdropsElements.WELCOME_TITLE.value
        with step('Airdrops welcome subtitle is correct'):
            assert airdrops_screen.airdrops_welcome_subtitle == AirdropsElements.WELCOME_SUBTITLE.value
        with step('Airdrops welcome checklist is correct'):
            assert AirdropsElements.WELCOME_CHECKLIST_ELEMENT_1.value == airdrops_screen.airdrops_checklist[0]
            assert AirdropsElements.WELCOME_CHECKLIST_ELEMENT_2.value == airdrops_screen.airdrops_checklist[1]
            assert AirdropsElements.WELCOME_CHECKLIST_ELEMENT_3.value == airdrops_screen.airdrops_checklist[2]
        with step('Airdrops infobox title and text are correct and button Mint Owner Token is visible'):
            assert str(airdrops_screen.airdrops_infobox_title) == AirdropsElements.INFOBOX_TITLE.value
            assert str(airdrops_screen.airdrops_infobox_text) == AirdropsElements.INFOBOX_TEXT.value
            assert airdrops_screen.mint_owner_token_button.is_visible

    with step('Open tokens view from community settings'):
        tokens_screen = community_setting.left_panel.open_tokens()

    with step('Verify all elements on tokens screen'):
        with step('Verify Mint token button is disabled'):
            assert tokens_screen.mint_token_button.exists, \
                f'Mint token button should be present'
        with step('Tokens welcome image path is correct'):
            assert TOKENS_WELCOME_IMAGE_PATH in str(tokens_screen.tokens_welcome_image_path)
        with step('Tokens welcome title is correct'):
            assert tokens_screen.tokens_welcome_title == TokensElements.WELCOME_TITLE.value
        with step('Tokens welcome subtitle is correct'):
            assert tokens_screen.tokens_welcome_subtitle == TokensElements.WELCOME_SUBTITLE.value
        with step('Tokens welcome checklist is correct'):
            assert TokensElements.WELCOME_CHECKLIST_ELEMENT_1.value == tokens_screen.tokens_checklist[0]
            assert TokensElements.WELCOME_CHECKLIST_ELEMENT_2.value == tokens_screen.tokens_checklist[1]
            assert TokensElements.WELCOME_CHECKLIST_ELEMENT_3.value == tokens_screen.tokens_checklist[2]
        with step('Tokens infobox title and text are correct and button Mint Owner Token is visible'):
            assert tokens_screen.tokens_infobox_title == TokensElements.INFOBOX_TITLE.value
            assert tokens_screen.tokens_infobox_text == TokensElements.INFOBOX_TEXT.value
            assert tokens_screen.mint_owner_token_button.is_visible, \
                f'Mint token owner token button should be enabled'

    with step('Open permissions in community settings'):
        permissions_settings = community_setting.left_panel.open_permissions()

    with step('Verify all elements on permissions screen'):
        with step('Verify Add permission button is visible'):
            assert permissions_settings._add_new_permission_button.exists, \
                f'Add new permission button should be visible'
        with step('Permission welcome image source path is correct'):
            assert PERMISSION_WELCOME_IMAGE_PATH in str(permissions_settings.permission_welcome_image_source)
        with step('Permission welcome title is correct'):
            assert permissions_settings.permission_welcome_title == PermissionsElements.WELCOME_TITLE.value
        with step('Permission welcome subtitle is correct'):
            assert permissions_settings.permission_welcome_subtitle == PermissionsElements.WELCOME_SUBTITLE.value
        with step('Permission welcome checklist is correct'):
            assert PermissionsElements.WELCOME_CHECKLIST_ELEMENT_1.value == permissions_settings.permission_checklist[0]
            assert PermissionsElements.WELCOME_CHECKLIST_ELEMENT_2.value == permissions_settings.permission_checklist[1]
            assert PermissionsElements.WELCOME_CHECKLIST_ELEMENT_3.value == permissions_settings.permission_checklist[2]
