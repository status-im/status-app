import allure
import pytest

from constants import DEFAULT_PIN, KEYCARD_PROFILE_DETAILS_TITLE
from helpers.keycard_helper import (
    assert_status_account_matches_seed,
    create_keycard_profile_from_seed,
    read_keycard_details,
)
from scripts.utils.generators import random_mnemonic


@pytest.mark.keycard
@pytest.mark.timeout(300)
@allure.title('Onboarding — Import existing seed onto card + create profile')
@allure.description(
    'Empty card → Create profile → Use Keycard → PIN → Import from recovery phrase → '
    'Create PIN → Enter generated seed → Continue on success → land in app → '
    'Keycard settings → Read Keycard → details appear → Wallet settings address matches seed'
)
def test_onboarding_import_seed_onto_empty_keycard(keycard_simulator, main_window):
    seed_phrase = random_mnemonic()
    create_keycard_profile_from_seed(keycard_simulator, main_window, seed_phrase)
    assert_status_account_matches_seed(main_window, seed_phrase)
    read_keycard_details(main_window, DEFAULT_PIN, KEYCARD_PROFILE_DETAILS_TITLE)
