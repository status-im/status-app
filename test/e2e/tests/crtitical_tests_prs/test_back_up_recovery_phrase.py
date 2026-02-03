import pytest
from allure import step

import constants
from driver.aut import AUT
from gui.components.back_up_your_seed_phrase_banner import BackUpSeedPhraseBanner

from gui.main_window import MainWindow


@pytest.mark.case(703421, 703010, 738725, 738758, 738771)
@pytest.mark.critical  # TODO 'https://github.com/status-im/status-desktop/issues/13013'
@pytest.mark.smoke
def test_back_up_recovery_phrase_sign_out(
        aut: AUT, main_screen: MainWindow, user_account):
    with step('Open online identifier and check the data'):
        online_identifier = main_screen.left_panel.open_online_identifier()
        assert online_identifier.get_user_name == user_account.name, \
            f'Display name in online identifier is wrong, current: {online_identifier.get_user_name}, expected: {user_account.name}'

    with step('Verify that user avatar background color'):
        avatar_color = str(main_screen.left_panel.profile_button.object.identicon.asset.bgColor.name).upper()
        assert avatar_color in constants.UserPictureColors.profile_colors(), \
            f'Avatar color should be one of the allowed colors but is {avatar_color}'

    with step('Open user profile from online identifier and check the data'):
        online_identifier = main_screen.left_panel.open_online_identifier()
        profile_popup = online_identifier.open_profile_popup_from_online_identifier()
        profile_popup_user_name = profile_popup.user_name
        assert profile_popup_user_name == user_account.name, \
            f'Display name in user profile is wrong, current: {profile_popup_user_name}, expected: {user_account.name}'

    with step('Open share profile popup and check the data'):
        share_profile_popup = profile_popup.share_profile()
        assert share_profile_popup.is_profile_qr_code_visibile, f'QR code is not displayed'
        share_profile_popup.close()
        main_screen.left_panel.click()

    with step('Click Back up seed card in home page and back up seed'):
        home = main_screen.left_panel.open_home_screen().wait_for_home_ui_loaded()
        assert not BackUpSeedPhraseBanner().back_up_seed_banner.exists, "Back up seed banner should not be seen on home page"
        back_up_seed_modal = home.open_back_up_seed_popup_from_home_page()
        back_up_seed_modal.back_up_seed_phrase_and_delete()

    with step('Verify notification after removing seed phrase'):
        messages = main_screen.wait_for_toast_notifications()
        assert f'Recovery phrase permanently removed from Status application storage' in messages, f'Messages: {messages}'

    with step('Go to settings screen from dock and check back up seed phrase banner is not shown there'):
        settings = main_screen.left_panel.open_settings()
        assert not settings.left_panel.settings_section_back_up_seed_option.exists, f"Back up seed option is present"
        assert not BackUpSeedPhraseBanner().back_up_seed_banner.exists, "Back up seed banner is present"

    with step('Click sign out and quit in settings'):
        sign_out_screen = settings.left_panel.open_sign_out_and_quit()
        sign_out_screen.sign_out_and_quit()
