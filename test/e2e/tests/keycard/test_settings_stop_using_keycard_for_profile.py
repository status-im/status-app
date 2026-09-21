import allure
import pytest

from configs.timeouts import APP_LOAD_TIMEOUT_MSEC
from constants import (
    DEFAULT_PIN,
    KEYCARD_ON_DEVICE_LABEL,
    KEYCARD_ON_KEYCARD_LABEL,
    KEYCARD_PROFILE_MOVED_TO_STATUS_TITLE,
)
from driver.aut import AUT
from gui.screens.onboarding import ReturningLoginView
from helpers.keycard_helper import (
    assert_status_account_matches_seed,
    create_keycard_profile_from_seed,
)
from helpers.onboarding_helper import (
    skip_post_login_popups_if_visible,
    wait_until_logged_in,
)
from helpers.settings_helper import open_wallet_settings
from scripts.utils.generators import random_mnemonic

NEW_PASSWORD = 'StatusPass1!'


@pytest.mark.keycard
@pytest.mark.timeout(500)
@allure.title('Wallet settings — Stop using Keycard for profile key pair')
@allure.description(
    'Keycard profile → Wallet settings → profile keypair menu → Stop using Keycard → '
    'confirm → seed → new password → re-encrypt → restart without clicking Quit → '
    'password login → keypair shows On device'
)
def test_settings_stop_using_keycard_for_profile(keycard_simulator, main_window, aut: AUT):
    seed_phrase = random_mnemonic()
    create_keycard_profile_from_seed(keycard_simulator, main_window, seed_phrase)

    wallet_settings = open_wallet_settings(main_window)
    keypair_name = wallet_settings.get_keypairs_names()[0]
    assert KEYCARD_ON_KEYCARD_LABEL in wallet_settings.get_keypair_location(keypair_name)

    keycard_mng_popup = wallet_settings.open_keypair_keycard_menu(keypair_name)
    keycard_mng_popup.confirm_selected_key_pair()
    keycard_mng_popup.enter_recovery_phrase(seed_phrase.split())
    keycard_mng_popup.create_and_confirm_password(NEW_PASSWORD)
    keycard_mng_popup.wait_until_success(
        KEYCARD_PROFILE_MOVED_TO_STATUS_TITLE,
        APP_LOAD_TIMEOUT_MSEC * 3,
    )

    aut.restart()
    main_window.prepare()
    login_view = ReturningLoginView().wait_until_appears(APP_LOAD_TIMEOUT_MSEC)
    assert login_view.password_box.is_visible, 'Expected password login after stopping Keycard for profile'
    login_view.log_in_with_password(NEW_PASSWORD)
    wait_until_logged_in(main_window)
    skip_post_login_popups_if_visible()

    assert_status_account_matches_seed(main_window, seed_phrase)
    wallet_settings = open_wallet_settings(main_window)
    assert KEYCARD_ON_DEVICE_LABEL in wallet_settings.get_keypair_location(keypair_name)
